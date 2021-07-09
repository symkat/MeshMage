package MeshMage::Web;
use Mojo::Base 'Mojolicious', -signatures;
use MeshMage::DB;
use Minion;
use Mojo::File qw( curfile );
use Mojo::Home;
use Try::Tiny;

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

    my $db = MeshMage::DB->connect(
        'dbi:Pg:host=localhost;dbname=meshmage', 'meshmage', 'meshmage'
    );
    $self->helper( db => sub { return $db } );

    # The location we'll stick files for download.
    $self->helper( download_dir => sub {
        return state $download = sprintf( "%s/%s", $self->static->paths->[0], 'download/' );
    });
    $self->helper( files_dir => sub {
        return state $home = Mojo::Home->new->detect . "/files";
    });

    # Setup Plugins
    $self->plugin( Minion => { Pg => 'postgresql://minion:minion@localhost:5433/minion' } );
    $self->plugin( 'MeshMage::Web::Plugin::MinionTasks' );
    $self->plugin( 'MeshMage::Web::Plugin::Helpers' );
    
    # Router
    my $r = $self->routes;

    # Handle user login & first account creation.
    # Routes:
    #   /login    GET view_login, POST post_login
    #   /first    GET view_first, POST post_first
    #   /logout   GET     logout, 
    $self->plugin( 'MeshMage::Web::Plugin::UserManagement' => { } );

    # Ensure that only authenticated users can access routes under
    # $auth.
    my $auth = $r->under( '/' => sub ($c) {

        # Login via session cookie.
        if ( $c->session('uid') ) {
            my $person = $c->db->resultset('Person')->find( $c->session('uid') );

            if ( $person && $person->is_enabled ) {
                $c->stash->{person} = $person;
                return 1;
            }
            $c->redirect_to( $c->url_for( 'view_login' ) );
            return undef;
        }

        $c->redirect_to( $c->url_for( 'view_login' ) );
        return undef;
    });
     
    $self->plugin( 'Minion::Admin' => { route => $auth->under( '/minion' ) } );
    
    # Send requests for / to the dashboard.
    $auth->get('/')->to(cb => sub ($c) {
        $c->redirect_to( $c->url_for('dashboard') ) 
    });

    # Controllers to create new things.
    $auth->get ('/create/network')->to('Create#network'       )->name('new_network'   );
    $auth->post('/create/network')->to('Create#create_network')->name('create_network');
    $auth->get ('/create/node'   )->to('Create#node'          )->name('new_node'      );
    $auth->post('/create/node'   )->to('Create#create_node'   )->name('create_node'   );
    $auth->get ('/create/sshkey' )->to('Create#sshkey'        )->name('new_sshkey'    );
    $auth->post('/create/sshkey' )->to('Create#create_sshkey' )->name('create_sshkey' );

    # Controllers to handle deploying/adopting nodes.
    $auth->get ('/deploy/manual/:node_id'   )->to('Deploy#manual'          )->name('deploy_manual'   );
    $auth->post('/deploy/macos'             )->to('Deploy#create_macos'    )->name('create_macos'    );
    $auth->get ('/deploy/automatic/:node_id')->to('Deploy#automatic'       )->name('deploy_automatic');
    $auth->post('/deploy/automatic'         )->to('Deploy#create_automatic')->name('create_automatic');

    # Controllers for the dashboard to view the networks.
    $auth->get('/dashboard'                    )->to('Dashboard#index'        )->name('dashboard'    );
    $auth->get('/dashboard/nodes'              )->to('Dashboard::Node#list'   )->name('list_nodes'   );
    $auth->get('/dashboard/node/:node_id'      )->to('Dashboard::Node#view'   )->name('view_node'    );
    $auth->get('/dashboard/networks'           )->to('Dashboard::Network#list')->name('list_networks');
    $auth->get('/dashboard/network/:network_id')->to('Dashboard::Network#view')->name('view_network' );
    $auth->get('/dashboard/sshkeys'            )->to('Dashboard::Sshkeys#list')->name('list_sshkeys' );
    $auth->get('/dashboard/sshkeys/:sshkey_id' )->to('Dashboard::Sshkeys#view')->name('view_sshkey'  );
}

1;
