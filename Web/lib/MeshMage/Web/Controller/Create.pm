package MeshMage::Web::Controller::Create;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Net::Subnet;
use Try::Tiny;

sub network ($c) {
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( networks => \@networks );
}

sub create_network ($c) {

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
    
    $c->redirect_to( $c->url_for( 'view_network', network_id => $network->id )->query( new => 1 ) );
}

sub node ($c) {
    my @nodes    = $c->db->resultset('Node')->all();
    my @networks = $c->db->resultset('Network')->all();

    $c->stash( nodes => \@nodes, networks => \@networks );
}

sub create_node ($c) {
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

sub sshkey ($c) {
    my @sshkeys = $c->db->resultset('Sshkey')->all();

    $c->stash( sshkeys => \@sshkeys );
}

sub create_sshkey ($c) {

    if ( $c->param('key_method') eq 'generate' ) {
        $c->minion->enqueue( 'generate_sshkey' => [ $c->param('key_desc') ]);
        $c->redirect_to( $c->url_for( 'dashboard' )->query( notice => 'ssh-generate' ) );
    } else {
        $c->minion->enqueue( 'import_sshkey' => [ $c->param('key_desc'), $c->param('private_key'), $c->param('public_key') ]);
        $c->redirect_to( $c->url_for( 'dashboard' )->query( notice => 'ssh-import' ) );
    }
}

sub user ($c) {

}

sub create_user ($c) {

    my $person = try {
        $c->db->storage->schema->txn_do( sub {
            my $person = $c->db->resultset('Person')->create({
                email => $c->param('email'),
                name  => $c->param('name'),
            });
            $person->new_related('auth_password', {})->set_password($c->param('password'));
            return $person;
        });
    } catch {
        push @{$c->stash->{errors}}, "Account could not be created: $_";
    };

    if ( $c->stash->{errors} ) {
        $c->render( template => 'create/user');
        return 0;
    }

    $c->session->{uid} = $person->id;

    $c->redirect_to( $c->url_for( 'list_users' ) );
}

sub password ($c) {

}

sub create_password ($c) {
    my $old_password     = $c->stash->{old_password}     = $c->param('old_password');
    my $password         = $c->stash->{password}         = $c->param('password');
    my $password_confirm = $c->stash->{password_confirm} = $c->param('password_confirm');

    push @{$c->stash->{errors}}, "Current password required."
        unless $old_password;

    push @{$c->stash->{errors}}, "New password required."
        unless $password;

    push @{$c->stash->{errors}}, "Confirm new password required."
        unless $password_confirm;

    push @{$c->stash->{errors}}, "Password and confirmation must match."
        unless $password eq $password_confirm;

    push @{$c->stash->{errors}}, "Your current password was incorrect."
        unless $c->stash->{person}->auth_password->check_password( $old_password );

    if ( $c->stash->{errors} ) {
        $c->render( template => 'create/password');
        return 0;
    }

    $c->stash->{person}->auth_password->update_password( $password );

    $c->redirect_to( $c->url_for( 'dashboard' )->query( notice => 'password' ) );
}


1;
