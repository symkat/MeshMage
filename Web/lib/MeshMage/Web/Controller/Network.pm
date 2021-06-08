package MeshMage::Web::Controller::Network;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( networks => \@networks );
}

sub create ($c) {
    
    $c->minion->enqueue( 'create_network_cert' => [
        $c->param('network_name'), $c->param('network_tld'), $c->param('network_cidr') 
    ]);
    
    $c->redirect_to( '/network' );
}

1;
