package MeshMage::Web::Controller::Sshkeys;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @sshkeys = $c->db->resultset('Sshkey')->all();

    $c->stash( sshkeys => \@sshkeys );
}

sub show ($c) {
    my $key = $c->db->resultset('Sshkey')->find( $c->param('id') );
    my $pub = Mojo::File->new( $c->config->{sshkey}{store} . "/" . $key->id . ".pub" )->slurp;

    $c->stash( key => { info => $key, content => $pub } );
}

sub create ($c) {

    if ( $c->param('key_method') eq 'generate' ) {
        $c->minion->enqueue( 'generate_sshkey' => [ $c->param('key_desc') ]);
    } else {
        $c->minion->enqueue( 'import_sshkey' => [ $c->param('key_desc'), $c->param('private_key'), $c->param('public_key') ])
    }
    
    $c->redirect_to( '/sshkeys' );
}

1;
