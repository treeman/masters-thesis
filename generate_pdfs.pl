#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use Getopt::Long;
use File::Basename;
use File::Spec;
use File::Copy;

my $help; # Shall I show you some guidance?
my $verbose; # Or shall I show you too much?

my $base = dirname($0);

Getopt::Long::Configure ("bundling");
GetOptions(
    'h|help' => \$help,
    'v|verbose' => \$verbose,
);

my $tmp_dir = File::Spec->join($base, "tmp");
mkdir $tmp_dir unless -d $tmp_dir;

# keyword => [source_file, output_file]
my %files = (
    planning => ["planning/report.tex", "planning-report.pdf"],
);

# Normalize paths
for my $val (values %files) {
    my @arr = map { $_ = File::Spec->join($base, $_) } @$val;
    $val = \@arr;
}

# Collect options
my %found;
for my $opt (@ARGV) {
    if ($files{$opt}) {
        $found{$opt} = 1;
    }
    else {
        say "Error, unexpected option: '$opt' found!";
        exit;
    }
}

# Did we find any options?
my $num_options = keys %found;
my $make_all = $num_options == 0;

# Generate the pdfs
while (my ($key, $val) = each %files) {
    my ($src, $dst) = @$val;

    next unless $found{$key} || $make_all;

    # pdflatex will generate a pdf in the same directory as $src
    # we want to find the name of that file, and move it to $dst
    if ($src !~ m|.*?([^/]+)\.tex|) {
        say "I have failed you! No match for '$src'";
        exit;
    }
    my $tmp_file = File::Spec->join($tmp_dir, "$1.pdf");

    # Yes I did it this way!
    my $cmd = "pdflatex -output-directory=$tmp_dir $src";
    if ($verbose) {
        say "$cmd";
        system($cmd);
    }
    else {
        say "Generating $dst...";
        `$cmd`;
    }
    say "move($tmp_file, $dst)" if $verbose;
    move($tmp_file, $dst);
}

if ($help) {
    my $name = basename($0);
    my $allowed_options = join("|", sort keys %files);

    say <<"END";
Generate pdfs.

Usage:
  $name [$allowed_options]
  $name -h | --help

Options:
  -h --help     Show this screen.
END
    exit;
}

