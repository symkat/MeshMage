package MeshMage::Web::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Try::Tiny;

sub init ($c) {
    my $user_count = $c->db->resultset('Person')->count;
    if ( $user_count >= 1 ) {
        $c->redirect_to( $c->url_for( 'auth_login' ) );
        return;
    }
}

sub create_init ($c) {
    # This code should only run when there are no user accounts, if
    # a user account exists, redirect the user to the login panel.
    my $user_count = $c->db->resultset('Person')->count;
    if ( $user_count >= 1 ) {
        $c->redirect_to( $c->url_for( 'view_login' ) );
        return;
    }

    my $person = try {
        $c->db->storage->schema->txn_do( sub {
            my $person = $c->db->resultset('Person')->create({
                email => $c->param('email'),
                name  => $c->param('name'),
            });
            $person->new_related('auth_password', {})->set_password($c->param('password'));
            return $person;
        });
    } catch {
        push @{$c->stash->{errors}}, "Account could not be created: $_";
        return;
    };

    $c->session->{uid} = $person->id;

    $c->redirect_to( $c->url_for( 'dashboard' ) );
}

sub login ($c) {
    # If we have no user accounts, redirect the user to the
    # initial create user page.
    my $user_count = $c->db->resultset('Person')->count;
    if ( $user_count == 0 ) {
        $c->redirect_to( $c->url_for( 'auth_init' ) );
        return;
    }
}

sub create_login ($c) {
    my $email    = $c->stash->{form_email}    = $c->param('email');
    my $password = $c->stash->{form_password} = $c->param('password');

    my $person = $c->db->resultset('Person')->find( { email => $email } )
        or push @{$c->stash->{errors}}, "Invalid email address or password.";
    
    return if $c->stash->{errors};

    $person->auth_password->check_password( $password )
        or push @{$c->stash->{errors}}, "Invalid email address or password.";
    
    return if $c->stash->{errors}; 

    $c->session->{uid} = $person->id;
    
    $c->redirect_to( $c->url_for( 'dashboard' ) );
}

sub logout ($c) {
    undef $c->session->{uid};
    $c->redirect_to( $c->url_for( 'auth_login' ) );

}

1;
