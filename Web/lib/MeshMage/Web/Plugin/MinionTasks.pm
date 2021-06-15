package MeshMage::Web::Plugin::MinionTasks; 
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use IPC::Run3;
use File::Path qw( make_path );
use File::Temp;

sub register ( $self, $app, $config ) {

    $app->minion->add_task( create_network_cert => sub ( $job, $network_name, $network_tld, $network_cidr ) {

        # Add this network to the DB.
        my $network = $job->app->db->resultset('Network')->create({
            name    => $network_name,
            tld     => $network_tld,
            address => $network_cidr,
        });

        # Create the storage location for this network.
        make_path($job->app->filepath_for(nebula => $network->id));
        
        # Create the network cert and signing key.
        run3( [ $job->app->config->{nebula}->{nebula_cert}, 'ca',
            '-out-crt', $job->app->filepath_for(nebula => $network->id, 'ca.crt'),
            '-out-key', $job->app->filepath_for(nebula => $network->id, 'ca.key'),
            '-name'   , $network_name,
        ]);
    });

    $app->minion->add_task( generate_sshkey => sub ( $job, $comment ) {
        run3( [ qw( ssh-keygen -t rsa -b 4096 -q -C ), $comment, '-N', '', '-f', $job->app->filepath_for( sshkey => 'new_key' )]);
        my $private_key = Mojo::File->new( $job->app->filepath_for(sshkey => "/new_key"    ))->slurp;
        my $public_key  = Mojo::File->new( $job->app->filepath_for(sshkey => "/new_key.pub"))->slurp;
        unlink $job->app->filepath_for( sshkey => "/new_key" );
        unlink $job->app->filepath_for( sshkey => "/new_key.pub");

        my $key = $job->app->db->resultset('Sshkey')->create({
            name       => $comment,
            public_key => $public_key
        });
        
        Mojo::File->new( $job->app->filepath_for(sshkey => $key->id         ))->spurt($private_key);
        Mojo::File->new( $job->app->filepath_for(sshkey => $key->id . '.pub'))->spurt($public_key );
    });
    
    $app->minion->add_task( import_sshkey => sub ( $job, $comment, $private_key, $public_key ) {
        my $key = $job->app->db->resultset('Sshkey')->create({
            name       => $comment,
            public_key => $public_key,
        });

        Mojo::File->new($job->app->filepath_for(sshkey => $key->id         ))->spurt($private_key);
        Mojo::File->new($job->app->filepath_for(sshkey => $key->id . '.pub'))->spurt($public_key );

    });

    $app->minion->add_task( deploy_node => sub ( $job, $node_id, $key_id, $deploy_ip ) {
        my $node = $job->app->db->resultset('Node')->find( $node_id );
        my @lighthouses = $node->network->search_related( 'nodes', { is_lighthouse => 1 } );

        my $playbook = File::Temp->new(
            TEMPLATE => 'playbook-XXXX', 
            SUFFIX   => '.yml', 
            UNLINK   => 0,
            DIR      => $job->app->config->{ansible}{rundir},
        );

        # Create a nebula config file for this domain so that Ansible may use
        # the file.
        Mojo::File->new( $job->app->filepath_for( nebula => $node->network->id, $node->hostname . '.yml' ))
            ->spurt( $job->app->make_nebula_config( $node ));

        
        print $playbook "- name: Configure Nebula Node\n";
        print $playbook "  remote_user: root\n"; 
        print $playbook "  vars:\n";
        print $playbook "    ansible_ssh_common_args: -oControlMaster=auto -oControlPersist=60s -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no\n";
        print $playbook "    domain: " . $node->hostname . "\n";
        print $playbook "    meshnet_store: " . $job->app->filepath_for( 'nebula' ) . "\n";
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
            '--key-file', $job->app->filepath_for( sshkey => $key_id ),
             $playbook->filename  
        ]);
    });
    
    $app->minion->add_task( create_node => sub ( $job, $network_id, $is_lighthouse, $hostname, $address, $public ) {
        my $network = $job->app->db->resultset('Network')->find( $network_id );

        # Make sure hostname is plain word, or matches the TLD for the network.

        # Make sure the IP address isn't used, and is within the network range.
        
        # If is_lighthouse, ensure public IP exists.
        
        my $domain = sprintf( "%s.%s", $hostname, $network->tld );

        my $cidr = (split( /\//, $network->address))[1];

        $network->create_related( 'nodes', {
            hostname      => $domain,
            nebula_ip     => $address,
            is_lighthouse => $is_lighthouse ? 1 : 0,
            ( $public ? ( public_ip => $public ) : () ),
        });

        my $command = [ $job->app->config->{nebula}->{nebula_cert}, 'sign',
            '-ca-crt',  $job->app->filepath_for( nebula => $network->id, "ca.crt" ),
            '-ca-key',  $job->app->filepath_for( nebula => $network->id, "ca.key" ),
            '-name',    $domain,
            '-ip',      "$address/$cidr",
            '-out-crt', $job->app->filepath_for( nebula => $network->id, "$domain.crt" ),
            '-out-key', $job->app->filepath_for( nebula => $network->id, "$domain.key" ),
        ];
        run3( $command );
    });
}

1;
