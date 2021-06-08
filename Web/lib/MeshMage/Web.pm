package MeshMage::Web;
use Mojo::Base 'Mojolicious', -signatures;
use MeshMage::DB;
use Minion;
use IPC::Run3;
use File::Path qw( make_path );
use File::Temp;

# This method will run once at server start
sub startup ($self) {

    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig', { file => 'meshmage.yml' });

    # Configure the application
    $self->secrets($config->{secrets});

    # Use Text::Xslate for the templates.
    $self->plugin(xslate_renderer => {
        template_options => {
            syntax => 'Metakolon',
        }
    });

    my $db = MeshMage::DB->connect(
        'dbi:Pg:host=localhost;dbname=meshmage', 'meshmage', 'meshmage'
    );
    $self->helper( db => sub { return $db } );

    # Setup Minion Job Queue
    # NOTE: https://docs.mojolicious.org/Mojolicious/Plugin/Minion/Admin When auth exists,
    # make sure that this plugin uses the same protection as other machine bits.
    $self->plugin( Minion => { Pg => 'postgresql://minion:minion@localhost:5433/minion' } );
    $self->plugin( 'Minion::Admin' );

    # Router
    my $r = $self->routes;

    # User Management
    $r->get( '/login' ) ->render( );

    # Adopt A Machine
    $r->get   ('/adopt')             ->to('Adopt#get_adopt');
    $r->post  ('/adopt')             ->to('Adopt#create_adopt');

    # Network Creation / Listing
    $r->get   ('/network')           ->to('Network#index');
    $r->get   ('/network/new')       ->to('Network#create');
    $r->post  ('/network')           ->to('Network#create');

    # Connect Nodes
    $r->get   ('/node')              ->to('Node#index');
    $r->post  ('/node')              ->to('Node#create');

    $r->get   ('/deploy')            ->to('Deploy#index');
    $r->get   ('/deploy/:node_id')   ->to('Deploy#deploy');
    $r->post  ('/deploy')            ->to('Deploy#create');
    
    # Manual Deployment
    $r->get   ('/manual')            ->to('Manual#index');
    $r->get   ('/manual/:node_id')   ->to('Manual#deploy');
    $r->post  ('/manual')            ->to('Manual#create');

    $r->get   ('/sshkeys')            ->to('Sshkeys#index');
    $r->get   ('/sshkeys/:id')        ->to('Sshkeys#show');
    $r->post  ('/sshkeys')            ->to('Sshkeys#create');





    # Network Configuration
    $r->get   ('/nebula' )           ->to('Nebula#show_network');
    $r->post  ('/nebula' )           ->to('Nebula#create_network');

    # Machine List / Manage
    $r->get   ('/machine')           ->to('Machine#list_machine');
    $r->get   ('/machine/:id')       ->to('Machine#get_machine');

    $r->post  ('/machine')           ->to('Machine#create_machine');
    $r->post  ('/machine/:id/update')->to('Machine#update_machine');
    $r->post  ('/machine/:id/delete')->to('Machine#delete_machine');

    # Normal route to controller
    $r->get('/')                     ->to('Dashboard#index');
    $r->get('/dashboard')            ->to('Dashboard#index');


    ## Long Running Jobs.
    $self->minion->add_task( create_network_cert => sub ( $job, $network_name, $network_tld, $network_cidr ) {

        # Add this network to the DB.
        my $network = $job->app->db->resultset('Network')->create({
            name    => $network_name,
            tld     => $network_tld,
            address => $network_cidr,
        });

        # Create the storage location for this network.
        make_path( $job->app->config->{nebula}->{store} . "/" . $network->id );
        
        # Create the network cert and signing key.
        run3( [ $self->config->{nebula}->{nebula_cert}, 'ca',
            '-out-crt', sprintf( "%s/%d/ca.crt", $job->app->config->{nebula}->{store}, $network->id ),
            '-out-key', sprintf( "%s/%d/ca.key", $job->app->config->{nebula}->{store}, $network->id ), 
            '-name'   , $network_name,
        ]);
    });

    $self->minion->add_task( generate_sshkey => sub ( $job, $comment ) {
        my $key = $job->app->db->resultset('Sshkey')->create({
            name => $comment,
        });

        run3( [ qw( ssh-keygen -t rsa -b 4096 -q -C ), $comment, '-N', '', '-f', $job->app->config->{sshkey}{store} . "/" . $key->id  ] );
    });
    
    $self->minion->add_task( import_sshkey => sub ( $job, $comment, $private_key, $public_key ) {
        my $key = $job->app->db->resultset('Sshkey')->create({
            name => $comment,
        });

        Mojo::File->new( $job->app->config->{sshkey}{store} . "/" . $key->id          )->spurt( $private_key );
        Mojo::File->new( $job->app->config->{sshkey}{store} . "/" . $key->id . ".pub" )->spurt( $public_key );

    });

    $self->minion->add_task( deploy_node => sub ( $job, $node_id, $key_id, $deploy_ip ) {
        my $node = $job->app->db->resultset('Node')->find( $node_id );
        my @lighthouses = $node->network->search_related( 'nodes', { is_lighthouse => 1 } );

        my $playbook = File::Temp->new(
            TEMPLATE => 'playbook-XXXX', 
            SUFFIX   => '.yml', 
            UNLINK   => 0,
            DIR      => $job->app->config->{ansible}{rundir},
        );
        
        print $playbook "- name: Configure Nebula Node\n";
        print $playbook "  remote_user: root\n"; 
        print $playbook "  vars:\n";
        print $playbook "    ansible_ssh_common_args: -oControlMaster=auto -oControlPersist=60s -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no\n";
        print $playbook "    domain: " . $node->hostname . "\n";
        print $playbook "    meshnet_store: " . $job->app->config->{nebula}{store} . "\n";
        print $playbook "    network_id: " . $node->network->id . "\n";
        print $playbook "    node:\n";
        print $playbook "      is_lighthouse: " . $node->is_lighthouse . "\n"; 
        print $playbook "    lighthouses:\n";

        foreach my $lighthouse ( @lighthouses ) {
        print $playbook "      - public_ip: " . $lighthouse->public_ip . "\n";
        print $playbook "        nebula_ip: " . $lighthouse->nebula_ip . "\n";
        }
        print $playbook "  hosts: all\n";
        print $playbook "  roles:\n";
        print $playbook "    - meshmage-node\n";

        $playbook->flush;
        close $playbook;

        run3([ 'ansible-playbook', '-i', "$deploy_ip,", 
            '--key-file', $job->app->config->{sshkey}{store} . "/$key_id", 
             $playbook->filename  
        ]);
    });
    
    $self->minion->add_task( create_node => sub ( $job, $network_id, $is_lighthouse, $hostname, $address, $public ) {
        my $network = $job->app->db->resultset('Network')->find( $network_id );

        # Make sure hostname is plain word, or matches the TLD for the network.

        # Make sure the IP address isn't used, and is within the network range.
        
        # If is_lighthouse, ensure public IP exists.
        
        my $store_path = $job->app->config->{nebula}->{store} . "/" . $network->id . "/";

        my $domain = sprintf( "%s.%s", $hostname, $network->tld );

        my $cidr = (split( /\//, $network->address))[1];

        $network->create_related( 'nodes', {
            hostname      => $domain,
            nebula_ip     => $address,
            is_lighthouse => $is_lighthouse ? 1 : 0,
            ( $public ? ( public_ip => $public ) : () ),
        });

        my $command = [ $self->config->{nebula}->{nebula_cert}, 'sign',
            '-ca-crt',  $store_path . "ca.crt",
            '-ca-key',  $store_path . "ca.key",
            '-name',    $domain,
            '-ip',      "$address/$cidr",
            '-out-crt', $store_path . "$domain.crt",
            '-out-key', $store_path . "$domain.key",
        ];
        run3( $command );
    });
}

1;
