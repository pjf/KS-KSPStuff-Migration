#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
use autodie;
use Data::Dumper;

# Migrate KS URLs to KSPStuff.
# Paul '@pjf' Fenwick, Feb 2016
# License: Same as Perl 5 itself.

my $DEBUG = 1;

my $kspstuff_manifest = "kspstuff-files.txt";

# Build a hash of all the end-files on KSPStuff,
# and their full paths. We also pick up the mod name
# and version, although it looks like we won't actually
# need that.

my $kspstuff_paths = read_paths($kspstuff_manifest);

say Dumper $kspstuff_paths if $DEBUG;

sub read_paths {
    my $manifest = shift;

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

        $kspstuff_path{$file} = $_;
    }

    return \%kspstuff_path;
}
