package MeshMage::Web::Controller::Manual;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) {
    my @nodes = $c->db->resultset('Node')->all();

    $c->stash( nodes => \@nodes );
}

sub deploy ($c) {
    my $node = $c->db->resultset('Node')->find( $c->param('node_id') );
    
    my $path = sprintf( "%s/%s", $c->config->{nebula}{store}, $node->network->id );

    my $ca   = Mojo::File->new( "$path/ca.crt" )->slurp;
    my $cert = Mojo::File->new( sprintf( "%s/%s.crt", $path, $node->hostname ) )->slurp;
    my $key  = Mojo::File->new( sprintf( "%s/%s.key", $path, $node->hostname ) )->slurp;

    $c->stash( 
        node => $node,
        ca   => $ca,
        cert => $cert,
        key  => $key,
        conf => $c->make_nebula_config( $node ),
     );
}

1;
