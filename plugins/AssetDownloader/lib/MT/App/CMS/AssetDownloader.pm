package MT::App::CMS::AssetDownloader;

use strict;
use MT::App;
use AssetDownloader::Util qw( site_path is_user_can get_user str2array );

@MT::App::CMS::AssetDownloader::ISA = qw( MT::App );

sub init_request {
    my $app = shift;
    $app->SUPER::init_request( @_ );
    $app->{ default_mode } = 'download';
    $app->add_methods( download => \&_download );
    if ( _is_requires_login() ) {
        $app->{ requires_login } = 1;
    }
    $app;
}

sub _download {
    my $app = shift;
    my $plugin = MT->component( 'AssetDownloader' );
    my $blog_id = $app->param( 'blog_id' );
    if ( _is_requires_login() ) {
        if ( my $permission = $plugin->get_config_value( 'require_permission' ) ) {
            if ( (! $blog_id ) || (! $app->blog ) ) {
                return $app->trans_error( 'Permission denied.' );
            }
            my $can_access;
            $can_access = 1 if $permission eq '*';
            if (! $can_access ) {
                my $user = get_user( $app );
                my @perms = str2array( $permission, ',', 1 );
                for my $perm ( @perms ) {
                    if ( is_user_can( $app->blog, $user, $perm ) ) {
                        $can_access = 1;
                    }
                }
            }
            return $app->trans_error( 'Permission denied.' ) unless $can_access;
        }
    }
    my $asset_id = $app->param( 'asset_id' );
    my $pi = $app->path_info;
    return $app->trans_error( 'Invalid request.' ) unless $asset_id;
    require MT::Asset;
    my $asset = MT::Asset->load( $asset_id );
    return $app->trans_error( 'File not found: [_1]', 'ID:' . $asset_id ) unless defined $asset;
    if ( $blog_id && ( $blog_id != $asset->blog_id ) ) {
        return $app->trans_error( 'Invalid request.' );
    }
    my $class = $asset->class;
    my $label = $asset->label;
    my $filename = $asset->file_name;
    my $ua = $app->get_header( 'USER_AGENT' );
    my $isIe = 1 if ( ( $ua =~ /MSIE/ ) && ( $ua !~ /Opera/ ) );
    my $isSafari = 1 if ( $ua =~ /Safari/ );
    my $print_header;
    if ( (! $plugin->get_config_value( 'download_image' ) ) && ( $class eq 'image' ) ) {
        $print_header = 1;
    }
    if ( $label ) {
        my $ext = $asset->file_ext;
        $label =~ s/\.$ext$//;
        $label .= '.' . $ext;
        if ( $isIe ) {
            $label = MT::I18N::encode_text( $label, 'utf8', 'cp932' );
        } elsif ( $isSafari ) {
            unless ( $pi ) {
                my $return_uri = $app->base . $app->uri . '/' . $label . '?asset_id=' . $asset_id;
                $return_uri .= '&blog_id=' . $blog_id if $blog_id;
                $app->redirect( $return_uri );
                return;
            }
        }
    } else {
        $label = $filename;
    }
    my $mime_type = $asset->mime_type;
    my $file_path = $asset->file_path;
    my $blog_id = $asset->blog_id;
    require MT::Blog;
    my $blog = MT::Blog->load( $blog_id );
    my $site_path = site_path( $blog );
    $file_path =~ s/%r/$site_path/;
    if ( -f $file_path ) {
        require MT::FileMgr;
        my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
        if (! $print_header ) {
            $app->{ no_print_body } = 1;
            if ( ( $isSafari ) &&  ( $pi ) ) {
                $app->set_header( 'Content-Disposition' => "attachment; filename=" );
            } else {
                $app->set_header( 'Content-Disposition' => "attachment; filename=$label" );
            }
            $app->set_header( 'pragma' => '' );
        }
        $app->send_http_header( $mime_type );
        print $fmgr->get_data( $file_path, 'upload' );
    } else {
        return $app->trans_error( 'File not found: [_1]', $filename );
    }
}

sub _is_requires_login {
    if ( my $plugin = MT->component( 'AssetDownloader' ) ) {
        return $plugin->get_config_value( 'requires_login' );
    }
}

1;