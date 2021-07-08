package MeshMage::Web::Controller::Deploy;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub manual ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my $n_id = $node->network->id;
    my $host = $node->hostname;

    my $ca   = Mojo::File->new( $c->filepath_for( nebula => $n_id, 'ca.crt' ) )->slurp;
    my $cert = Mojo::File->new( $c->filepath_for( nebula => $n_id, $host . '.crt') )->slurp;
    my $key  = Mojo::File->new( $c->filepath_for( nebula => $n_id, $host . '.key') )->slurp;

    $c->stash( 
        node      => $node,
        ca        => $ca,
        cert      => $cert,
        key       => $key,
        conf      => $c->templated_file( 'nebula_config.yml', node => $node ),
        platforms => $c->nebula_platforms,
     );
}

sub create_macos ($c) {

    my $node     = $c->db->resultset('Node')->find( $c->param('node_id') );
    my $platform = $c->param('platform');

    my $job_id = $c->minion->enqueue( create_macos_bundle => [ $node->id, $platform ],
        { notes => { $node->hostname => 1 } }
    );

    $c->redirect_to(
        $c->url_for( 'view_node', node_id => $node->id )->query(
            pending => sprintf( "%s_macos.tgz", $node->hostname )
        )
    );
}


# Automatic Deployment
sub automatic ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my @keys = $c->db->resultset('Sshkey')->all();

    $c->stash( 
        node      => $node,
        sshkeys   => \@keys,
        platforms => $c->nebula_platforms,
        
    );
}

sub create_automatic ($c) {

    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );

    my $job_id = $c->minion->enqueue(
        deploy_node => [ 
            $node->id, 
            $c->param('sshkey_id'), 
            $c->param('deploy_ip'),
            $c->param('platform'),
        ],
        { notes => { $node->hostname => 1 } }
    );

    $c->redirect_to( $c->url_for( 'view_node', node_id => $node->id ) );
}

1;
