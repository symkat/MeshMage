package MeshMage::Web::Controller::Deploy::Manual;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @nodes = $c->db->resultset('Node')->all();

    $c->stash( nodes => \@nodes );
}

sub deploy ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my $n_id = $node->network->id;
    my $host = $node->hostname;

    my $ca   = Mojo::File->new( $c->filepath_for( nebula => $n_id, 'ca.crt' ) )->slurp;
    my $cert = Mojo::File->new( $c->filepath_for( nebula => $n_id, $host . '.crt') )->slurp;
    my $key  = Mojo::File->new( $c->filepath_for( nebula => $n_id, $host . '.key') )->slurp;

    $c->stash( 
        node => $node,
        ca   => $ca,
        cert => $cert,
        key  => $key,
        conf => $c->make_nebula_config( $node ),
     );
}

1;
