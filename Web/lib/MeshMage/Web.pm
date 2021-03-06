package MeshMage::Web;
use Mojo::Base 'Mojolicious', -signatures;
use MeshMage::DB;
use Minion;
use Mojo::File qw( curfile );
use Mojo::Home;
use Try::Tiny;
use DateTime;

# This method will run once at server start
sub startup ($self) {

    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig', { file => 'meshmage.yml' });

    # Configure the application
    $self->secrets($config->{secrets});

    # Use Text::Xslate for the templates.
    $self->plugin(xslate_renderer => {
        template_options => {
            syntax => 'Metakolon',
        }
    });

    # Set the cookie expires to 30 days.
    $self->sessions->default_expiration(2592000);

    $self->helper( db => sub { 
        return state $db = MeshMage::DB->connect($config->{database}->{meshmage});
    } );

    # The location we'll stick files for download.
    $self->helper( download_dir => sub {
        return state $download = sprintf( "%s/%s", $self->static->paths->[0], 'download/' );
    });
    $self->helper( files_dir => sub {
        return state $home = Mojo::Home->new->detect . "/files";
    });

    # Setup Plugins
    $self->plugin( Minion => { Pg => $config->{database}->{minion} } );
    $self->plugin( 'RenderFile' );
    $self->plugin( 'MeshMage::Web::Plugin::MinionTasks' );
    $self->plugin( 'MeshMage::Web::Plugin::Helpers' );

    
    # Standard router.
    my $r = $self->routes;
    
    # Create a router chain that ensures the request is from an authenticated
    # user.
    my $auth = $r->under( '/' => sub ($c) {

        # Login through an X-Auth tokens (i.e. for curl commands)
        if ( $c->req->headers->header('X-Auth') ) {
            my $token = $c->req->headers->header('X-Auth');

            my $lower_time = DateTime->now;
               $lower_time->subtract( minutes => 15 );

            my $record = $c->db->resultset('AuthToken')->search({
                token      => $token,
                created_at => { '>=', $lower_time },
            })->first;

            if ( $record ) {
                $c->stash->{person} = $record->person_id;
                return 1;
            }
        }

        # Login via session cookie.
        if ( $c->session('uid') ) {
            my $person = $c->db->resultset('Person')->find( $c->session('uid') );

            if ( $person && $person->is_enabled ) {
                $c->stash->{person} = $person;
                return 1;
            }
            $c->redirect_to( $c->url_for( 'auth_login' ) );
            return undef;
        }

        $c->redirect_to( $c->url_for( 'auth_login' ) );
        return undef;
    });

    # Controllers to handle initial user creation, login and logout.
    $r->get ('/auth/init'  )->to('Auth#init'        )->name('auth_init'        );
    $r->post('/auth/init'  )->to('Auth#create_init' )->name('create_auth_init' );
    $r->get ('/auth/login' )->to('Auth#login'       )->name('auth_login'       );
    $r->post('/auth/login' )->to('Auth#create_login')->name('create_auth_login');
    $r->get ('/auth/logout')->to('Auth#logout'      )->name('logout'       );

    # The /minion stuff is handled here because we needed to place it under $auth.
    $self->plugin( 'Minion::Admin' => { route => $auth->under( '/minion' ) } );
    
    # A secure static file area, the user will need to be authenticated.
    $auth->get('/secure/#filename')->to( cb => sub ($c) {

        my $filepath = sprintf( "%s/secure_download/%s", $c->files_dir, $c->param('filename') );

        if ( ! -e $filepath ) {
            $c->res->code( 404 );
            $c->render( text => "No such file or directory.\n" );
            return;
        }

        $c->render_file(
            filepath => $filepath,
            filename => $c->param('filename'),
        );
    })->name( 'secure_file' );

    # Send requests for / to the dashboard.
    $auth->get('/')->to(cb => sub ($c) {
        $c->redirect_to( $c->url_for('dashboard') ) 
    });

    # Controllers to create new things.
    $auth->get ('/create/network' )->to('Create#network'        )->name('new_network'    );
    $auth->post('/create/network' )->to('Create#create_network' )->name('create_network' );
    $auth->get ('/create/node'    )->to('Create#node'           )->name('new_node'       );
    $auth->post('/create/node'    )->to('Create#create_node'    )->name('create_node'    );
    $auth->get ('/create/sshkey'  )->to('Create#sshkey'         )->name('new_sshkey'     );
    $auth->post('/create/sshkey'  )->to('Create#create_sshkey'  )->name('create_sshkey'  );
    $auth->get ('/create/user'    )->to('Create#user'           )->name('new_user'       );
    $auth->post('/create/user'    )->to('Create#create_user'    )->name('create_user'    );
    $auth->get ('/create/password')->to('Create#password'       )->name('new_password'   );
    $auth->post('/create/password')->to('Create#create_password')->name('create_password');

    # Controllers to handle deploying/adopting nodes.
    $auth->get ('/deploy/manual/:node_id'   )->to('Deploy#manual'          )->name('deploy_manual'   );
    $auth->post('/deploy/macos'             )->to('Deploy#create_macos'    )->name('create_macos'    );
    $auth->get ('/deploy/automatic/:node_id')->to('Deploy#automatic'       )->name('deploy_automatic');
    $auth->post('/deploy/automatic'         )->to('Deploy#create_automatic')->name('create_automatic');

    # Controllers for the dashboard to view the networks.
    $auth->get('/dashboard'                    )->to('Dashboard#index'        )->name('dashboard'    );
    $auth->get('/dashboard/users'              )->to('Dashboard#users'        )->name('list_users'   );
    $auth->get('/dashboard/nodes'              )->to('Dashboard::Node#list'   )->name('list_nodes'   );
    $auth->get('/dashboard/node/:node_id'      )->to('Dashboard::Node#view'   )->name('view_node'    );
    $auth->get('/dashboard/networks'           )->to('Dashboard::Network#list')->name('list_networks');
    $auth->get('/dashboard/network/:network_id')->to('Dashboard::Network#view')->name('view_network' );
    $auth->get('/dashboard/sshkeys'            )->to('Dashboard::Sshkeys#list')->name('list_sshkeys' );
    $auth->get('/dashboard/sshkeys/:sshkey_id' )->to('Dashboard::Sshkeys#view')->name('view_sshkey'  );
}

1;
