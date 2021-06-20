package MeshMage::Web::Controller::Deploy::Automatic;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @nodes = $c->db->resultset('Node')->all();

    $c->stash( nodes => \@nodes );
}

sub deploy ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    my @keys = $c->db->resultset('Sshkey')->all();

    $c->stash( 
        node      => $node,
        sshkeys   => \@keys,
        platforms => $c->nebula_platforms,
        
    );
}

sub create ($c) {

    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );

    my $job_id = $c->minion->enqueue(
        deploy_node => [ 
            $node->id, 
            $c->param('sshkey_id'), 
            $c->param('deploy_ip'),
            $c->param('platform'),
        ],
        { notes => { $node->hostname => 1 } }
    );

    $c->redirect_to( $c->url_for( 'view_node', node_id => $node->id ) );
}

1;
