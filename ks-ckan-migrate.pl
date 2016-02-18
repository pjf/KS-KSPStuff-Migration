#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
use autodie;
use utf8::all;
use autodie;
use File::Find;
use Data::Dumper;
use JSON::XS;
use File::Slurp qw(read_file write_file);
use Method::Signatures;
use Try::Tiny;
use Digest::SHA1 qw(sha1_hex);

my $DEBUG             = 0;
my $LOCAL_META        = "../CKAN-meta";
my $json              = JSON::XS->new->pretty;
my %rewrite;

my ($to_rewrite) = @ARGV;

if ($to_rewrite) {
    open(my $fh, '<', $to_rewrite);

    while (<$fh>) {
        chomp;
        $rewrite{$_}++;
    }
}

# Patch our metadata!
find( 
    sub {
        try {
            patch_metadata($_,%rewrite);
        }
        catch {
            say "Couldn't patch - $_";
        };
    },
    $LOCAL_META
);

func patch_metadata($filename, %rewrite) {
    # Skip anything but "regular" files (eg: directories)
    return if not -f $filename;

    # Skip anything but .ckan files.
    return if not $filename =~ /\.ckan$/;

    # Awright! Let's see if we've got a KS URL inside.
    open(my $ckan_fh, '<', $filename);

    my $metadata = $json->decode( scalar read_file($filename) );

    # Check the license!
    my $license = $metadata->{license};

    # Unknown or restricted license? Don't touch it.
    if ($license eq "restricted" or $license eq "unknown") {
        debug("Non-free license on $filename, skipping");
        return;
    }

    # All our other licenses are free. As in freedom.

    my $download_url = $metadata->{download};

    # Return unless this is a KS mod.

    return unless $download_url =~ m{
        kerbalstuff\.com/mod/\d+/
        (?<mod> [^/]+)
        /download/
        (?<version> .*)
        $
    }x;

    # Aww yis, it is!
    
    # Let's find its caching hash.

    my $hash = cache_hash($download_url);

    if ($rewrite{$hash}) {
        say "$hash # Re-writing $filename";

        my $new_url = "https://s3-us-west-2.amazonaws.com/ksp-ckan/$hash.zip";

        my $ckan = read_file($filename);

        # Yup, we're munging it with regexps, so all
        # the keys stay in order and we get a pretty
        # diff for git.

        $ckan =~ s{
            ("download"\s*:\s*)"$download_url"
        }{$1"$new_url"}msx or die "Failed to rewrite $filename";

        write_file($filename, $ckan);

    }
    else {
        # say "$hash # $filename";
    }

    return;

}

func cache_hash($url) {
    return uc substr(sha1_hex($url),0,8);
}

func debug($msg) {
    return if not $DEBUG;
    say STDERR $msg;
}
