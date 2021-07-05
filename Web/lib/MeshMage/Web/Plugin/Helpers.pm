package MeshMage::Web::Plugin::Helpers; 
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use File::Find;
use File::Path qw( make_path );
use Text::Xslate;

sub register ( $self, $app, $config ) {

    $app->helper( filepath_for => sub ( $c, $type, @file_segments ) {

        return undef unless $type;

        # Ensure whatever directory we're getting the filepath for
        # exists.
        make_path( sprintf( "%s/%s",
            $c->config->{filestore}{prefix},
            $c->config->{filestore}{$type}
        ));

        # Handle the case of ->( 'type', 'subdir1', 'subdir2', ..., )
        return sprintf( "%s/%s/%s",
            $c->config->{filestore}{prefix},
            $c->config->{filestore}{$type},
            join( "/", @file_segments ),
        ) if @file_segments;

        # Handle the standard case.
        return sprintf( "%s/%s",
            $c->config->{filestore}{prefix},
            $c->config->{filestore}{$type},
        );

    });

    # Helpers to get the nebula/nebula_cert binary paths for the
    # system running MeshMage.
    $app->helper( nebula_cert => sub ($c) { 
        return state $nebula_cert = sprintf( "%s/%s/nebula-cert",
            $c->config->{nebula}{store}, $c->config->{nebula}{use}
        );
    });
    
    $app->helper( nebula => sub ($c) {
        return state $nebula_cert = sprintf( "%s/%s/nebula",
            $c->config->{nebula}{store}, $c->config->{nebula}{use}
        );
    });

    # Helper to get the nebula binary path for systems we're uploading
    # to.
    $app->helper( nebula_for => sub ($c, $platform) {
        if ( $platform =~ m|^windows/| ) {
            return sprintf("%s/%s/nebula.exe", $c->config->{nebula}{store}, $platform);
        } else {
            return sprintf("%s/%s/nebula", $c->config->{nebula}{store}, $platform);
        }
    });

    # Helper to memoize the platforms list.
    $app->helper( nebula_platforms => sub ($c) {
        return state $platforms = _get_platforms($c->config->{nebula}{store});
    });


    # Helpers to handle templates of files, for example nebula
    # configuration files, ansible playlists and whatnot.
    $app->helper( xslate => sub ($c) {
        return state $xslate = Text::Xslate->new(
            type   => 'text',
            syntax => 'Metakolon',
            path   => $c->files_dir . "/templates",
        );
    });

    $app->helper( templated_file => sub ( $c, $file, %in ) {
        return $c->xslate->render("$file.tx", \%in);
    });
}

# List all of the platform combinations, like linux/amd64
# that are in the .nebula directory.
sub _get_platforms ($path) {
    my %platforms;

    find({ 
        wanted => sub {
            return if $path eq $_;                      # no top dir  
            my $rel = substr($_, (length($path) + 1) ); # $rel is linux/amd64/...
            my ( $os, $arch ) = split( m|/|, $rel );    # just first 2 segments
            return unless $os && $arch;                 # ensure both exist
            $platforms{"$os/$arch"} = 1;                # hash to unique
        },
        no_chdir => 1,
    }, $path );

    return [ sort { $a cmp $b } keys %platforms ];
}

1;
