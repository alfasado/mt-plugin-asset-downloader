package AssetDownloader::Util;
use Exporter;
@AssetDownloader::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( path2relative site_path is_user_can get_user str2array );

use strict;

sub path2relative {
    my ( $path, $blog ) = @_;
    my $app = MT->instance();
    my $static_file_path = quotemeta( static_or_support() );
    my $archive_path = quotemeta( archive_path( $blog ) );
    my $site_path = quotemeta( site_path( $blog ) );
    $path =~ s/$static_file_path/%s/;
    $path =~ s/$site_path/%r/;
    if ( $archive_path ) {
        $path =~ s/$archive_path/%a/;
    }
    if ( $path =~ m!^https{0,1}://! ) {
        my $site_url = quotemeta( site_url( $blog ) );
        $path =~ s/$site_url/%r/;
    }
    return $path;
}

sub is_user_can {
    my ( $blog, $user, $permission ) = @_;
    $permission = 'can_' . $permission;
    my $perm = $user->is_superuser;
    unless ( $perm ) {
        if ( $blog ) {
            my $admin = 'can_administer_blog';
            $perm = $user->permissions( $blog->id )->$admin;
            $perm = $user->permissions( $blog->id )->$permission unless $perm;
        } else {
            $perm = $user->permissions()->$permission;
        }
    }
    return $perm;
}

sub get_user {
    my $app = shift || MT->instance();
    my $user; my $sess;
    if ( is_application( $app ) ) {
        require MT::Session;
        require MT::Author;
        eval { $user = $app->user };
        unless ( defined $user ) {
            eval { ( $sess, $user ) = $app->get_commenter_session() };
            unless ( defined $user ) {
                if ( $app->param( 'sessid' ) ) {
                    my $sess = MT::Session->load ( { id => $app->param( 'sessid' ),
                                                     kind => 'US' } );
                    if ( defined $sess ) {
                       my $sess_timeout = $app->config->UserSessionTimeout;
                       if ( ( time - $sess->start ) < $sess_timeout ) {
                            $user = MT::Author->load( { name => $sess->name, status => MT::Author::ACTIVE() } );
                            $sess->start( time );
                            $sess->save or die $sess->errstr;
                        }
                    }
                }
            }
        }
        unless ( defined $user ) {
            if ( my $mobile_id = get_mobile_id( $app ) ) {
                my @authors = MT::Author->search_by_meta( mobile_id => $mobile_id );
                if ( my $author = $authors[0] ) {
                    if ( $author->status == MT::Author::ACTIVE() ) {
                        $user = $author;
                    }
                }
            }
        }
    }
    return $user if defined $user;
    return undef;
}

sub site_path {
    my $blog = shift;
    my $site_path;
    my $site_path = $blog->site_path;
    return chomp_dir( $site_path );
}

sub site_url {
    my $blog = shift;
    my $site_url = $blog->site_url;
    $site_url =~ s{/+$}{};
    return $site_url;
}

sub archive_path {
    my $blog = shift;
    my $archive_path = $blog->archive_path;
    return chomp_dir( $archive_path );
}

sub static_or_support {
    my $app = MT->instance();
    my $static_or_support;
    if ( MT->version_number < 5 ) {
        $static_or_support = $app->static_file_path;
    } else {
        $static_or_support = $app->support_directory_path;
    }
    return $static_or_support;
}

sub chomp_dir {
    require File::Spec;
    my $dir = shift;
    my @path = File::Spec->splitdir( $dir );
    $dir = File::Spec->catdir( @path );
    return $dir;
}

sub is_application {
    my $app = shift || MT->instance();
    return (ref $app) =~ /^MT::App::/ ? 1 : 0;
}

sub get_mobile_id {
    my ( $app, $to_hash ) = @_;
    my $mobile_id;
    my $user_agent = $app->get_header( 'User-Agent' );
    my @browswer = split( m!/!, $user_agent );
    my $ua = $browswer[0];
    if ( $ua eq 'DoCoMo' ) {
        if ( $user_agent =~ /^.*(ser[0-9]{11,}).*$/ ) {
            $mobile_id = $1;
        }
    } elsif ( $ua =~ /UP\.Browser/ ) {
        my $x_up_subno = $user_agent = $app->get_header( 'X_UP_SUBNO' );
        # AU
        if ( $x_up_subno ) {
            $mobile_id = $x_up_subno;
        }
    } elsif ( ( $ua eq 'SoftBank' ) || ( $ua eq 'Vodafone' ) ) {
        # Softbank
        my $x_jphone_uid = $app->get_header( 'X_JPHONE_UID' );
        if ( $x_jphone_uid ) {
            $mobile_id = $x_jphone_uid;
        }
    }
    if ( $mobile_id && $to_hash ) {
        $mobile_id = perl_sha1_digest_hex( $mobile_id );
    }
    return $mobile_id if $mobile_id;
    return '';
}

sub str2array {
    my ( $str, $separator, $remove_space ) = @_;
    return unless $str;
    $separator ||= ',';
    my @items = split( $separator, $str );
    if ( $remove_space ) {
        @items = map { $_ =~ s/\s+//g; $_ } @items;
    }
    if ( wantarray ) {
        return @items;
    }
    return \@items;
}

1;