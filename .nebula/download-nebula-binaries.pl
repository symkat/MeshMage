#!/usr/bin/env perl
use v5.10;
use warnings;
use strict;
use LWP::UserAgent;
use LWP::Simple qw( getstore );
use HTML::TreeBuilder;
use File::Basename;
use File::Path qw( make_path );
use Cwd;
use IPC::Run3;

sub ua {
    return state $ua = LWP::UserAgent->new(timeout => 30);
}

my $res = ua->get( "https://github.com/slackhq/nebula/releases/tag/v1.4.0" );
my @links = HTML::TreeBuilder->new_from_content($res->decoded_content)->look_down( 
    _tag => 'a', 
    sub { 
        ref($_[0])          && 
        $_[0]->can('attr')  && 
        $_[0]->attr('href') =~ m|/slackhq/nebula/releases/download/|
    },
);

foreach my $link ( @links ) {
    my $href = $link->attr('href');
    my $filename = (split( m|/|, $href ))[-1];

    if ( $filename =~ /^nebula-([^-]+)-([^\.]+)\.((?:tar\.gz|zip))$/ ) {
        my ( $os, $arch, $ext ) = ( $1, $2, $3 );
        
        print "Downloading $filename...\n";
        make_path( "$os/$arch" );
        getstore( "https://github.com/$href", "$os/$arch/$filename" );
        print "Unpacking $filename in $os/$arch\n";
        untar_or_unzip( "$os/$arch", $filename );

    } elsif ( $filename eq 'SHASUM256.txt' ) {
        getstore( "https://github.com/$href", $filename );
    } else {
        warn "I don't recognize $filename, skipping.\n";
    }
}

sub untar_or_unzip {
    my ( $path, $filename ) = @_;

    my $before = getcwd;

    chdir $path;

    run3( [ qw( tar -xzf ), $filename ] )
        if $filename =~ /tar\.gz$/;

    run3( [ unzip => $filename ] )
        if $filename =~ /zip$/;

    chdir $before;

}
