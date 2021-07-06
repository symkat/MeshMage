package MeshMage::Web::Controller::Deploy::MacOS;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create ($c) {

    my $node     = $c->db->resultset('Node')->find( $c->param('node_id') );
    my $platform = $c->param('platform');

    my $job_id = $c->minion->enqueue( create_macos_bundle => [ $node->id, $platform ],
        { notes => { $node->hostname => 1 } }
    );

    $c->redirect_to(
        $c->url_for( 'view_node', node_id => $node->id )->query(
            pending => sprintf( "%s_macos.tgz", $node->hostname )
        )
    );
}

1;
