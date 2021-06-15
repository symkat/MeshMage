package MeshMage::Web;
use Mojo::Base 'Mojolicious', -signatures;
use MeshMage::DB;
use Minion;

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

    my $db = MeshMage::DB->connect(
        'dbi:Pg:host=localhost;dbname=meshmage', 'meshmage', 'meshmage'
    );
    $self->helper( db => sub { return $db } );

    # Setup Minion Job Queue
    # NOTE: https://docs.mojolicious.org/Mojolicious/Plugin/Minion/Admin When auth exists,
    # make sure that this plugin uses the same protection as other machine bits.
    $self->plugin( Minion => { Pg => 'postgresql://minion:minion@localhost:5433/minion' } );
    $self->plugin( 'Minion::Admin' );
    $self->plugin( 'MeshMage::Web::Plugin::MinionTasks' );
    $self->plugin( 'MeshMage::Web::Plugin::NebulaConfig' );
    $self->plugin( 'MeshMage::Web::Plugin::Helpers' );

    # Router
    my $r = $self->routes;

    # User Management
    $r->get( '/login' ) ->render( );

    # Adopt A Machine
    $r->get   ('/adopt')             ->to('Adopt#get_adopt');
    $r->post  ('/adopt')             ->to('Adopt#create_adopt');

    # Network Creation / Listing
    $r->get   ('/network')           ->to('Network#index');
    $r->get   ('/network/new')       ->to('Network#create');
    $r->post  ('/network')           ->to('Network#create');

    # Connect Nodes
    $r->get   ('/node')              ->to('Node#index');
    $r->post  ('/node')              ->to('Node#create');

    $r->get   ('/deploy')            ->to('Deploy#index');
    $r->get   ('/deploy/:node_id')   ->to('Deploy#deploy');
    $r->post  ('/deploy')            ->to('Deploy#create');
    
    # Manual Deployment
    $r->get   ('/manual')            ->to('Manual#index');
    $r->get   ('/manual/:node_id')   ->to('Manual#deploy');
    $r->post  ('/manual')            ->to('Manual#create');

    $r->get   ('/sshkeys')            ->to('Sshkeys#index');
    $r->get   ('/sshkeys/:id')        ->to('Sshkeys#show');
    $r->post  ('/sshkeys')            ->to('Sshkeys#create');


    # Normal route to controller
    $r->get('/')                     ->to('Dashboard#index');
    $r->get('/dashboard')            ->to('Dashboard#index');

}

1;
