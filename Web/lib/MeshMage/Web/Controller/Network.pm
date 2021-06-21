package MeshMage::Web::Controller::Network;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( networks => \@networks );
}

sub create ($c) {

    my $name = $c->param('network_name');
    my $tld  = $c->param('network_tld');
    my $cidr = $c->param('network_cidr');

    my $network = $c->db->resultset('Network')->create({
        name    => $name,
        tld     => $tld,
        address => $cidr,
    });

    $c->minion->enqueue( 'create_network_cert' => [ $network->id ],
        { notes => { $network->tld => 1 } }
    );
    
    # $c->minion->enqueue( 'create_network_cert' => [
    #     $c->param('network_name'), $c->param('network_tld'), $c->param('network_cidr') 
    # ]);
    
    $c->redirect_to( $c->url_for( 'view_network', network_id => $network->id )->query( new => 1 ) );
}

1;
