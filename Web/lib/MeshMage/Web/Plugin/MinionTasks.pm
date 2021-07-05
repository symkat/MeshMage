package MeshMage::Web::Plugin::MinionTasks; 
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use IPC::Run3;
use File::Path qw( make_path );
use File::Temp;
use Try::Tiny;
use Net::Subnet;
use Mojo::File;

sub register ( $self, $app, $config ) {

    # create_network_cert
    #
    # This task will create the network directory and keys.  The directory is expected
    # to be new, if it already exists we'll throw an error.
    #
    $app->minion->add_task( create_network_cert => sub ( $job, $network_id ) {

        my $network = $job->app->db->resultset('Network')->find( $network_id );

        if ( ! $network ) {
            $job->fail( "No network with ID $network_id" );
            return;
        }

        my $network_path = $job->app->filepath_for(nebula => $network->id);

        my $count = make_path($network_path);
        if ( $count != 1 ) {
            $job->fail("Existing network found at $network_path, delete this directory and retry this job.");
            return;
        }

        run3( [ $job->app->nebula_cert, 'ca',
            '-out-crt', "$network_path/ca.crt",
            '-out-key', "$network_path/ca.key",
            '-name'   , $network->name,
        ]);

        $job->finish();
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
    
    $app->minion->add_task( create_macos_intel_bundle => sub ( $job, $node_id ) {
        my $node   = $job->app->db->resultset('Node')->find( $node_id );
        my $domain = $node->hostname; 
        my $net_id = $node->network->id;

        # TODO - This might need machine-specific configuration, let's abide that.
        #
        # Make Nebula Configuration File For Packing
        Mojo::File->new( $job->app->filepath_for(nebula => $net_id, "$domain.yml"))
            ->spurt( $job->app->templated_file( 'nebula_config.yml', node => $node ));

        # Make a temp dir, and inside it put a nebula dir, we'll 
        # end up taring up the nebula directory as the bundle.
        my $tempdir = File::Temp->newdir();
        my $dir     = "$tempdir/nebula";
        make_path( $dir );

        my $etc_path = $job->app->files_dir;
        my $net_path = $job->app->filepath_for( nebula => $net_id );
        my $neb_path = $job->app->nebula_for('darwin/amd64' ); # TODO - This can accept a platform, and
                                                               #        and then we can use one bundle task
                                                               #        for everything.

        # Pack these files for the user.
        Mojo::File->new( "$net_path/$domain.crt"        )->copy_to( $dir                );
        Mojo::File->new( "$net_path/$domain.key"        )->copy_to( $dir                );
        Mojo::File->new( "$net_path/$domain.yml"        )->copy_to( $dir                );
        Mojo::File->new( "$net_path/ca.crt"             )->copy_to( $dir                );
        Mojo::File->new( "$neb_path"                    )->copy_to( $dir                )->chmod(0755);
        Mojo::File->new( "$etc_path/uninstall-macos.sh" )->copy_to( "$dir/uninstall.sh" )->chmod(0775);
        Mojo::File->new( "$etc_path/install-macos.sh"   )->copy_to( "$dir/install.sh"   )->chmod(0775);
        Mojo::File->new( "$etc_path/README-macos.txt"   )->copy_to( "$dir/README.txt"   );
        Mojo::File->new( "$etc_path/Nebula.plist"       )->copy_to( $dir                );

        # my $outfile = $job->app->filepath_for( nebula => $net_id, "${domain}_macos_intel.tgz" )VC
        my $outfile = $job->app->download_dir . "${domain}_macos_intel.tgz";

        my $command = [qw( tar -C ), $tempdir, '-czf', $outfile, 'nebula' ];
        run3( $command );
    });

    $app->minion->add_task( deploy_node => sub ( $job, $node_id, $key_id, $deploy_ip, $platform ) {
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
            ->spurt( $job->app->templated_file( 'nebula_config.yml', node => $node ));

        print $playbook $job->app->templated_file( 'ansible-playbook.yml',
            node     => $node,
            app      => $job->app,
            platform => $platform
        );
        $playbook->flush;
        close $playbook;

        run3([ 'ansible-playbook', '-i', "$deploy_ip,", 
            '--key-file', $job->app->filepath_for( sshkey => $key_id ),
             $playbook->filename  
        ]);
    });
    
    # create_node_cert
    #
    # Create the nebula certs for the node and sign them.
    #
    $app->minion->add_task( create_node_cert => sub ( $job, $node_id ) {

        my $node = $job->app->db->resultset('Node')->find( $node_id );
        if ( ! $node ) {
            $job->fail( "No node with id $node_id was found" );
            return;
        }

        my $network = $node->network;
        my $domain  = $node->hostname;
        my $cidr    = (split( /\//, $network->address))[1];
        my $address = $node->nebula_ip;

        my $command = [ $job->app->nebula_cert, 'sign',
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
