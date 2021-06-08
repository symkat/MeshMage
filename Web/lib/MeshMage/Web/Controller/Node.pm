package MeshMage::Web::Controller::Node;
use Mojo::Base 'Mojolicious::Controller', -signatures;

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

1;
