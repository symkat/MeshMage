package MeshMage::Web::Plugin::MinionTasks; 
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use IPC::Run3;
use File::Path qw( make_path );
use File::Temp;
use Try::Tiny;
use Net::Subnet;

sub register ( $self, $app, $config ) {

    # create_network_cert
    #
    # This task will create the network directory and keys.  The directory is expected
    # to be new, if it already exists we'll throw an error.
    #
    $app->minion->add_task( create_network_cert => sub ( $job, $network_name, $network_tld, $network_cidr ) {

        try {
            $job->app->db->txn_do(sub {
                # Add this network to the DB.
                my $network = $job->app->db->resultset('Network')->create({
                    name    => $network_name,
                    tld     => $network_tld,
                    address => $network_cidr,
                });

                # Create the storage location for this network.
                my $count = make_path($job->app->filepath_for(nebula => $network->id));
                die "Error: refusing to overwrite an existing network directory.\n"
                    unless $count == 1;

                # Create the network cert and signing key.
                run3( [ $job->app->config->{nebula}->{nebula_cert}, 'ca',
                    '-out-crt', $job->app->filepath_for(nebula => $network->id, 'ca.crt'),
                    '-out-key', $job->app->filepath_for(nebula => $network->id, 'ca.key'),
                    '-name'   , $network_name,
                ]);
            });
        } catch {
            $job->fail( $_ );
        } finally {
            $job->finish() unless shift;
        };
    });

    # generate_sshkey
    #
    # This task will generate an ssh keypair and then schedule it to be
    # imported with the task import_sshkey.
    #
    $app->minion->add_task( generate_sshkey => sub ( $job, $comment ) {

        # Get the name of a temp file to use for the SSH keypair.
        my $keyfile = File::Temp->new(TEMPLATE => 'XXXXXXXX', SUFFIX => '' );
        $keyfile->close;
        unlink $keyfile->filename;

        # Create SSH Key
        run3([qw( ssh-keygen -t rsa -b 4096 -q), '-C' => $comment, '-N' => '', '-f' => $keyfile->filename]);

        # Get the contents of the newly created keyfile pair.
        my $private_key = Mojo::File->new( $keyfile->filename          )->slurp;
        my $public_key  = Mojo::File->new( $keyfile->filename . '.pub' )->slurp;

        # Delete the files.
        unlink $keyfile->filename;
        unlink $keyfile->filename . '.pub';

        # Schedule an import of these keys.
        $job->app->minion->enqueue( import_sshkey => [ $comment, $private_key, $public_key ] );
    });
    
    # import_sshkey
    #
    # Given a comment and keypair, store the keypair for use, and also stuff the public key
    # into the DB so we can tell the user what it is later.
    #
    # If the public or private key file already exists, we will refuse to overwrite it and
    # throw an error, this error state will require manual intervention to correct.
    $app->minion->add_task( import_sshkey => sub ( $job, $comment, $private_key, $public_key ) {

        try {
            $job->app->db->txn_do(sub {
                my $key = $job->app->db->resultset('Sshkey')->create({
                    name       => $comment,
                    public_key => $public_key,
                });

                die "Error: refusing to overwrite existing ssh private key with id " . $key->id
                    if -e $job->app->filepath_for(sshkey => $key->id);

                die "Error: refusing to overwrite existing ssh public key with id " . $key->id
                    if -e $job->app->filepath_for(sshkey => $key->id);

                Mojo::File->new($job->app->filepath_for(sshkey => $key->id         ))->spurt($private_key);
                Mojo::File->new($job->app->filepath_for(sshkey => $key->id . '.pub'))->spurt($public_key );

                return 1;
            });
        } catch {
            $job->fail( $_ );
        } finally {
            $job->finish() unless shift;
        };
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
    
    # create_node
    #
    # Create the nebula certs for the node and sign them.
    #
    $app->minion->add_task( create_node => sub ( $job, $network_id, $is_lighthouse, $hostname, $address, $public ) {
        my $network = $job->app->db->resultset('Network')->find( $network_id );

        # Make sure hostname is plain word, or matches the TLD for the network.
        if ( index($hostname, '.') ) {
            my $tld   = $network->tld;

            $job->fail( "Error: $hostname must be plain word or FQDN ending with $tld" )
                unless $hostname =~ /\.\Q$tld\E$/;
            return;
        }
        
        # Set $domain to the FQDN for this node.
        my $domain = index($hostname, '.')
            ? $hostname
            : sprintf( "%s.%s", $hostname, $network->tld );

        # Make sure the IP address isn't used. -- Should overlapping networks be allowed?
        my $ip_is_used = $job->app->db->resultset('Node')->search( { nebula_ip => $address } )->count;
        if ( $ip_is_used ) {
            $job->fail( "IP address for Nebula, $address, is already used." );
            return;
        }

        # Make sure the address we're using is within the defined cidr for the network we're adding
        # the node to.
        my $is_in_network = subnet_matcher $network->address;
        if ( ! $is_in_network->($address) ) {
            $job->fail( "IP address for Nebula, $address, is not in range " . $network->address );
            return;
        }

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
