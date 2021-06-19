package MeshMage::Web::Controller::Dashboard::Sshkeys;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub list ($c) {
    my @sshkeys = $c->db->resultset('Sshkey')->all();

    $c->stash( sshkeys => \@sshkeys );
}

sub view ($c) {
    my $key = $c->db->resultset('Sshkey')->find( $c->param('sshkey_id') );
    my $pub = Mojo::File->new( $c->filepath_for(sshkey => $key->id . '.pub') )->slurp;

    $c->stash( key => { info => $key, content => $pub } );
}

1;
