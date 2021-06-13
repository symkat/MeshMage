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
        conf => make_config( $node ),
     );
}

sub make_config ( $node ) {

    my @lighthouses = $node->network->search_related( 'nodes', { is_lighthouse => 1 } )->all;

    my $lighthouse_block;
    my $lighthouse_hosts;
    foreach my $lighthouse ( @lighthouses ) {
        $lighthouse_block .= '  "' . $lighthouse->nebula_ip . '": ["' . $lighthouse->public_ip . ':4242"]' . "\n";
        $lighthouse_hosts .= '    - "' . $lighthouse->nebula_ip . '"' . "\n"; 
    }


    my $str = "pki:\n";
    $str   .= "  ca:   /etc/nebula/ca.crt\n";
    $str   .= "  cert: /etc/nebula/" . $node->hostname . ".crt\n";
    $str   .= "  key:  /etc/nebula/" . $node->hostname . ".key\n";
    $str   .= "\n";
    $str   .= "static_host_map:\n";
    $str   .= $lighthouse_block;
    $str   .= "\n";
    $str   .= "lighthouse:\n";
    $str   .= "  am_lighthouse: " . ( $node->is_lighthouse ? 'true' : 'false' ) . "\n";
    $str   .= "  serve_dns: " . ( $node->is_lighthouse ? 'true' : 'false' ) . "\n";
    $str   .= "  interval: 60\n";
    $str   .= "  hosts:\n";
    $str   .= $lighthouse_hosts if $node->is_lighthouse;
    $str   .= "\n";
    $str   .= "listen:\n";
    $str   .= "  host: 0.0.0.0\n";
    $str   .= "  port: " . ( $node->is_lighthouse ? "4242\n" : "0\n" );
    $str   .= "\n";
    $str   .= "punchy:\n";
    $str   .= "  punch: true\n";
    $str   .= "  respond: true\n";
    $str   .= "\n";
    $str   .= "tun:\n";
    $str   .= "  dev: nebula1\n";
    $str   .= "  drop_local_broadcast: false\n";
    $str   .= "  drop_multicast: false\n";
    $str   .= "  tx_queue: 500\n";
    $str   .= "  mtu: 1300\n";
    $str   .= "\n";
    $str   .= "logging:\n";
    $str   .= "  level: info\n";
    $str   .= "  format: text\n";
    $str   .= "\n";
    $str   .= "firewall:\n";
    $str   .= "  conntrack:\n";
    $str   .= "    tcp_timeout: 12m\n";
    $str   .= "    udp_timeout: 3m\n";
    $str   .= "    default_timeout: 10m\n";
    $str   .= "    max_connections: 100000\n";
    $str   .= "\n";
    $str   .= "  outbound:\n";
    $str   .= "    # Allow all outbound traffic from this node\n";
    $str   .= "    - port: any\n";
    $str   .= "      proto: any\n";
    $str   .= "      host: any\n";
    $str   .= "\n";
    $str   .= "  inbound:\n";
    $str   .= "    # Allow icmp between any nebula hosts\n";
    $str   .= "    - port: any\n";
    $str   .= "      proto: any\n";
    $str   .= "      host: any\n";

    return $str;
}

1;
