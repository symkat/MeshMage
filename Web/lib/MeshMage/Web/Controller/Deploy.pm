package MeshMage::Web::Controller::Deploy;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @nodes = $c->db->resultset('Node')->all();

    $c->stash( nodes => \@nodes );
}

sub deploy ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my @keys = $c->db->resultset('Sshkey')->all();

    $c->stash( node => $node, sshkeys => \@keys );
}

sub create ($c) {

    $c->minion->enqueue( 'deploy_node' => [ $c->param('node_id'), $c->param('sshkey_id'), $c->param('deploy_ip') ] );

    $c->redirect_to( '/node' );
}

1;
