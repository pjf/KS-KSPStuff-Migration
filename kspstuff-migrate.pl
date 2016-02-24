#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
use utf8::all;
use autodie;
use File::Find;
use Data::Dumper;
use JSON::XS;
use File::Slurp qw(read_file write_file);
use Method::Signatures;
use Try::Tiny;

# Migrate KS URLs to KSPStuff.
# Paul '@pjf' Fenwick, Feb 2016
# License: Same as Perl 5 itself.

my $DEBUG = 0;

my $kspstuff_manifest = "kspstuff-files.txt";
my $LOCAL_META        = "../CKAN-meta";
my $json              = JSON::XS->new->pretty;

# Build a hash of all the end-files on KSPStuff,
# and their full paths. We also pick up the mod name
# and version, although it looks like we won't actually
# need that.

my $kspstuff_paths = read_paths($kspstuff_manifest);

say Dumper $kspstuff_paths if $DEBUG;

# This is a curried, lexically scope function. It's
# less offensive to Haskell programmers.

my $patch_metadata = sub {
    patch_metadata($kspstuff_paths, $_[0]);
};

# Patch our metadata!
find( 
    sub {
        try {
            patch_metadata($kspstuff_paths, $_);
        }
        catch {
            say "Couldn't patch - $_";
        };
    },
    $LOCAL_META
);

func patch_metadata($kspstuff, $filename) {

    # Skip anything but "regular" files (eg: directories)
    return if not -f $filename;

    # Skip anything but .ckan files.
    return if not $filename =~ /\.ckan$/;

    # Awright! Let's what we've got.
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

    # Munge the name, since KS doesn't allow all characters in
    # filenames, and converts spaces to underscores.

    my ($mod, $version) = ($+{mod}, $+{version});
    $mod =~ s/%20/_/g;
    $mod =~ s/\.|%21|%27//g;

    # And try to patch the filename. This throws on failure.
    $metadata->{download} = patch_download($mod, $version, $kspstuff);

    # And write. :)

    # Previously we'd do a JSON dump here, but that changes key-ordering,
    # so instead we do some magic regexpes instead.

    my $content = read_file($filename);

    $content =~ s{"\Q$download_url\E"}{"$metadata->{download}"}msg
        or die "Failed to rewrite $filename";

    write_file($filename, $content);

    return;
}

func patch_download($mod, $version, $kspstuff) {
    my $path = $kspstuff->{$mod}{$version}
        or die "Can't find $mod ($version) on KerbalStuff\n";

    return "http://i.52k.de/kspmods/$path";
}

func read_paths($manifest) {
    open(my $manifest_fh, '<:crlf', $manifest);

    my %kspstuff_path;

    while (<$manifest_fh>) {
        chomp;
        my ($file, $mod, $version) = m{
            .*/                     # Find bottom-most directory
            (?<filename>
                (?<mod> [^-]+)
                -
                (?<version> .*?)
                \.zip
            )
            $
        }msx or die "Cannot parse $_";

        $kspstuff_path{$mod}{$version} = $_;
    }

    return \%kspstuff_path;
}

func debug($msg) {
    return if not $DEBUG;
    say STDERR $msg;
}
