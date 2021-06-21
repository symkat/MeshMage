package MeshMage::Web::Controller::Dashboard::Network;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub list ($c) {
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( networks => \@networks );
}

sub view ($c) {
    my $network = $c->db->resultset('Network')->find( $c->param('network_id') );
    my $jobs    = $c->minion->jobs( { notes => [ $network->tld ] } );

    $c->stash( network => $network, jobs => $jobs );
}

1;
