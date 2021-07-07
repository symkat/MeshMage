package MeshMage::Web::Plugin::UserManagement; 
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Try::Tiny;

sub register ( $self, $app, $config ) {

    my $r = $config->{route} || $app->routes;

    # User Management
    $r->get ( '/first' )->to( cb => sub ($c) {
        my $user_count = $c->db->resultset('Person')->count;
        if ( $user_count >= 1 ) {
            $c->redirect_to( $c->url_for( 'view_login' ) );
            return;
        }
        $c->render( template => 'first', format => 'html', handler => 'tx' );
    })->name( 'view_first' );

    $r->post( '/first' )->to( cb => sub ($c) {
        
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
            $c->render( template => 'first', format => 'html', handler => 'tx' );
            return;
        };

        $c->session->{uid} = $person->id;

        $c->redirect_to( $c->url_for( 'dashboard' ) );

    })->name( 'post_first' );

    $r->get ( '/login' )->to( cb => sub ($c) {

        # If we have no user accounts, redirect the user to the
        # initial create user page.
        my $user_count = $c->db->resultset('Person')->count;
        if ( $user_count == 0 ) {
            $c->redirect_to( $c->url_for( 'view_first' ) );
            return;
        }

        $c->render( template => 'login', format => 'html', handler => 'tx' );
    })->name( 'view_login' );

    $r->post( '/login' )->to( cb => sub ($c) {
        my $email    = $c->stash->{form_email}    = $c->param('email');
        my $password = $c->stash->{form_password} = $c->param('password');

        my $person = $c->db->resultset('Person')->find( { email => $email } )
            or push @{$c->stash->{errors}}, "Invalid email address or password.";
        
        if ( $c->stash->{errors} or not $person ) {
            $c->render( template => 'login', format => 'html', handler => 'tx' );
            return;
        }

        $person->auth_password->check_password( $password )
            or push @{$c->stash->{errors}}, "Invalid email address or password.";
        
        if ( $c->stash->{errors} ) {
            $c->render( template => 'login', format => 'html', handler => 'tx' );
            return;
        }

        $c->session->{uid} = $person->id;
        
        $c->redirect_to( $c->url_for( 'dashboard' ) );
    })->name( 'post_login' );

    $r->get ( '/logout' )->to( cb => sub ($c) {
        undef $c->session->{uid};
        $c->redirect_to( $c->url_for( 'view_login' ) );
    })->name( 'logout' );
}

1;
