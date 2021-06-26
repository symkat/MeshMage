package MeshMage::Web::Controller::Deploy::MacOS;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create ($c) {

    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );

    my $job_id = $c->minion->enqueue( create_macos_intel_bundle => [ $node->id ],
        { notes => { $node->hostname => 1 } }
    );

    $c->redirect_to( 
        $c->url_for( 'view_node', node_id => $node->id )
            ->query( 
                pending => sprintf( "%s_macos_intel.tgz", $node->hostname ) 
            )
    );
}

1;
