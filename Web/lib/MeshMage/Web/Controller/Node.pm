package MeshMage::Web::Controller::Node;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Net::Subnet;

sub index ($c) {
    my @nodes    = $c->db->resultset('Node')->all();
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( nodes => \@nodes, networks => \@networks );
}

sub create ($c) {
    my $network_id     = $c->param('network_id');
    my $is_lighthouse  = $c->param('is_lighthouse');
    my $hostname       = $c->param('hostname');
    my $nebula_address = $c->param('address');
    my $public_address = $c->param('public_address');
    my @networks       = $c->db->resultset('Network')->all();

    # If we reject the user later, have the template data filled in so their
    # form doesn't totally blank out.
    $c->stash(
        networks            => \@networks,
        form_address        => $nebula_address,
        form_public_address => $public_address,
        form_hostname       => $hostname,
        form_is_lighthouse  => $is_lighthouse,
        form_network_id     => $network_id,
    );

    # General having of things...
    push @{$c->stash->{errors}}, "No network selected."
        unless $network_id;

    push @{$c->stash->{errors}}, "You must enter an IP address."
        unless $nebula_address;

    push @{$c->stash->{errors}}, "You must enter a hostname."
        unless $hostname;

    if ( $c->stash->{errors} ) {
        $c->render( template => 'node/index', format => 'html', handler => 'tx' );
        return;
    }

    my $network = $c->db->resultset('Network')->find( $network_id );

    if ( ! $network ) {
        $c->stash( errors => [ "No network was found with that network_id (how'd you do that?)" ] );
        $c->render( template => 'node/index', format => 'html', handler => 'tx' );
        return;
    }

    # Verify the hostname makes sense.
    if ( CORE::index($hostname, '.') != -1 ) {
        my $tld   = $network->tld;

        if ( $hostname !~ /\.\Q$tld\E/ ) {
            $c->stash( errors => [ "Hostname must be plain word, or FQDN ending with $tld" ] );
            $c->render( template => 'node/index', format => 'html', handler => 'tx' );
            return;
        }
    }

    # Set $domain to the FQDN for this node.
    my $domain = CORE::index($hostname, '.') >= 0
        ? $hostname
        : sprintf( "%s.%s", $hostname, $network->tld );

    # Make sure the IP address isn't used. -- Should overlapping networks be allowed?
    my $ip_is_used = $c->db->resultset('Node')->search( { nebula_ip => $nebula_address } )->count;
    if ( $ip_is_used ) {
        $c->stash( errors => [ "IP address for node, $nebula_address, is already used." ] );
        $c->render( template => 'node/index', format => 'html', handler => 'tx' );
        return;
    }

    # Make sure the address we're using is within the defined cidr for the network we're adding
    # the node to.
    my $is_in_network = subnet_matcher $network->address;
    if ( ! $is_in_network->($nebula_address) ) {
        $c->stash( errors => [ "IP address for node, $nebula_address, is not in range " . $network->address ] );
        $c->render( template => 'node/index', format => 'html', handler => 'tx' );
        return;
    }

    my $cidr = (split( /\//, $network->address))[1];

    my $node = $network->create_related( 'nodes', {
        hostname      => $domain,
        nebula_ip     => $nebula_address,
        is_lighthouse => $is_lighthouse ? 1 : 0,
        ( $public_address ? ( public_ip => $public_address ) : () ),
    });

    # Do the node signing and such.
    $c->minion->enqueue( 'create_node_cert' => [ $node->id ],
        { notes => { $node->hostname => 1 } }
    );

    $c->redirect_to( $c->url_for( 'view_node', node_id => $node->id )->query( is_new => 1 ) );
}

1;
