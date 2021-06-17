package MeshMage::Web::Controller::Node;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw( encode_json );

sub index ($c) {
    my @nodes    = $c->db->resultset('Node')->all();
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( nodes => \@nodes, networks => \@networks );
}

sub create ($c) {

    $c->minion->enqueue( 'create_node' => [
        $c->param('network_id'), $c->param('is_lighthouse'), $c->param('hostname'), $c->param('address'), $c->param('public_address')
    ]);

    $c->redirect_to( '/node' );
}

sub show ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my $jobs = $c->minion->jobs( { notes => [ $node->hostname ] } );

    $c->stash(
        node => $node,
        jobs => $jobs,
    );
}

1;
