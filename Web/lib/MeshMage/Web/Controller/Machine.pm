package MeshMage::Web::Controller::Machine;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub list_machine ($c) {
    my @machines = $c->db->resultset('Machine')->search({})->all;

    $c->render(
        machines => \@machines,
    );
}

sub get_machine ($c) {
    my $machine = $c->db->resultset('Machine')->find($c->param('id') );
    
    if ( ! $machine ) {
        # Throw an error.
    }
    
    $c->render(
        machine => $machine,
    );
}

sub create_machine ($c) {
    my $hostname  = $c->param('hostname');
    my $public_ip = $c->param('public_ip');
    my $nebula_ip = $c->param('nebula_ip');
    
    $c->db->resultset('Machine')->create({
        hostname => $hostname,
        public_ip => $public_ip,
        nebula_ip => $nebula_ip,
    });

    $c->redirect_to( 'machine' );
}

sub delete_machine ($c) {

    my $machine = $c->db->resultset('Machine')->find( $c->param('id') );

    if ( ! $machine ) {
        # Throw an error.
    }

    $machine->delete;

    $c->redirect_to( 'machine' );
}

sub update_machine ($c) {
    my $action  = $c->param('action');
    my $machine = $c->db->resultset('Machine')->find( $c->param('id') );

    if ( $action eq 'add_attr' ) {
        my ( $name, $value ) = ( $c->param( 'name' ), $c->param('value') );

        $machine->attr( $name, $value );
        $c->redirect_to( "/machine/" . $c->param('id') );
    }

}

1;
