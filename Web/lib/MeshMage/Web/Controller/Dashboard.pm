package MeshMage::Web::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @networks = $c->db->resultset('Network')->all();
    my @nodes    = $c->db->resultset('Node')->all();
    my @sshkeys  = $c->db->resultset('Sshkey')->all();

    $c->stash( networks => \@networks, nodes => \@nodes, sshkeys => \@sshkeys );
}

1;
