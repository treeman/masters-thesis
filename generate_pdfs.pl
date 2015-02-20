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

# Show help and exit?
show_help() if $help;

my $tmp_dir = File::Spec->join($base, ".gen");
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
my %found = collect_options();

# Did we find any options?
my $make_all = keys %found == 0;

# Generate the pdfs
while (my ($key, $val) = each %files) {
    next unless $found{$key} || $make_all;

    my ($src, $dst) = @$val;
    generate_pdf($src, $dst);
}

sub generate_pdf {
    my ($src, $dst) = @_;

    # pdflatex will generate a pdf in the same directory as $src
    # we want to find the name of that file, and move it to $dst
    if ($src !~ m|.*?([^/]+)\.tex|) {
        say "I have failed you! No match for '$src'";
        exit;
    }
    my $tmp_file = File::Spec->join($tmp_dir, "$1.pdf");

    # Do command twice to force correct references
    my $cmd = "pdflatex -output-directory=$tmp_dir -halt-on-error $src";
    # system prints to stdout and backticks captures.
    # Simple way to control output
    if ($verbose) {
        say "$cmd";
        system($cmd);
        system($cmd);
    }
    else {
        say "Generating $dst...";
        `$cmd`;
        `$cmd`;
    }
    say "move(\"$tmp_file\", \"$dst\")" if $verbose;
    move($tmp_file, $dst);
}

sub collect_options {
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

    return %found;
}

sub show_help {
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
