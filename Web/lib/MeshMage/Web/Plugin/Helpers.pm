package MeshMage::Web::Plugin::Helpers; 
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ( $self, $app, $config ) {

    $app->helper( filepath_for => sub ( $c, $type, @file_segments ) {

        my $file = join( "/", @file_segments );
        return sprintf( "%s/%s/%s",
            $c->config->{filestore}{prefix},
            $c->config->{filestore}{$type},
            $file,
        ) if $file;

        return sprintf( "%s/%s",
            $c->config->{filestore}{prefix},
            $c->config->{filestore}{$type},
        );

    });
}

1;
