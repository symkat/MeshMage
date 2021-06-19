package MeshMage::Web::Controller::Dashboard::Node;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub list ($c) {
    my @nodes    = $c->db->resultset('Node')->all();
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( nodes => \@nodes, networks => \@networks );
}

sub view ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my $jobs = $c->minion->jobs( { notes => [ $node->hostname ] } );

    $c->stash(
        node => $node,
        jobs => $jobs,
    );
}

1;
