package AssetDownloader::Tags;

use strict;
use AssetDownloader::Util qw( path2relative );

sub _hdlr_download_script {
    my ( $ctx, $args, $cond ) = @_;
    return $ctx->{ config }->DownloadScript || 'mt-download.cgi';
}

sub _filter_url2download {
    my ( $text, $arg, $ctx ) = @_;
    $arg = 'href' if $arg eq '1';
    my $app = MT->instance();
    my $blog = $ctx->stash( 'blog' );
    require MT::Asset;
    my $match = '<[^>]+\s(' . $arg . ')\s*=\s*\"';
    for my $url ( $text =~ m!$match(.{1,}?)"!g ) {
        if ( $url =~ /^http/ ) {
            my $file_path = path2relative( $url, $blog );
            my $asset = MT::Asset->load( { blog_id => $blog->id, class => '*',
                                           file_path => $file_path } );
            if ( $asset ) {
                my $asset_id = $asset->id;
                my $script = _hdlr_download_script( $ctx );
                my $return_uri = $app->base . $app->path. $script . '?asset_id=' . $asset_id;
                $return_uri .= '&amp;blog_id=' . $blog->id;
                $text =~ s!($match)(.{1,}?)(")!$1$return_uri$4!g
            }
        }
    }
    return $text;
}

1;