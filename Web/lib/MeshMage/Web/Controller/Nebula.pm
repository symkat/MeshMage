package MeshMage::Web::Controller::Nebula;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub show_network ($c) {
    
}

sub create_network ($c) {
    
    $c->minion->enqueue( 'create_network_cert' => [ $c->param('network_name'), $c->param('network_cidr') ] );
}

1;
