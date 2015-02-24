#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use Getopt::Long;
use File::Basename;
use File::Spec;
use File::Copy;
use Cwd;

my $help;           # Shall I show you some guidance?
my $verbose;        # Or shall I show you too much?
my $show_cmds;      # Only the good parts?
my $clean;          # Dirty?

my $base = dirname($0);

Getopt::Long::Configure ("bundling");
GetOptions(
    'h|help' => \$help,
    'v|verbose' => \$verbose,
    'c|clean' => \$clean,
    'show_cmds' => \$show_cmds,
);

$show_cmds = 1 if $verbose;

my $tmp_dir = Cwd::abs_path(File::Spec->join($base, ".gen"));
mkdir $tmp_dir unless -d $tmp_dir;

# keyword => [source_file, output_file, bibliography?]
my %files = (
    planning => ["planning/report.tex", "planning-report.pdf", 0],
    report => ["report/main.tex", "report.pdf", 1],
);

# Normalize paths
for my $val (values %files) {
    # Hax away bibliography value :)
    my @arr = map { $_ = File::Spec->join($base, $_) } @$val[0..1];
    $val = [ @arr, @$val[2] ];
}

# Collect options
my %found = collect_options();

# Did we find any options?
my $make_all = keys %found == 0;

show_help() if $help; # Show help and exit?
clean() if $clean;    # Clean things and exit?

# Generate the pdfs
while (my ($key, $val) = each %files) {
    next unless $found{$key} || $make_all;

    generate_pdf(@$val);
}

sub generate_pdf {
    my ($src, $dst, $bibliography) = @_;

    # pdflatex will generate a pdf in the same directory as $src
    # we want to find the name of that file, and move it to $dst
    if ($src !~ m|.*?([^/]+)\.tex|) {
        say "I have failed you! No match for '$src'";
        exit;
    }
    my $tmp_file = File::Spec->join($tmp_dir, "$1.pdf");
    my $aux_file = "$1.aux";

    # Need to cd to directory as pdflatex cannot find packages otherwise
    my $src_dir = dirname($src);
    my $src_base = basename($src);

    # Hacky workaround for pdflatex lack of module system
    # Could not find another way! :)
    #
    # Generate a report with bibliography:
    #
    # 0. Clear $tmp_dir
    clean_tmp();
    # 1. Copy all files to $tmp_dir, as the commands works in the current directory
    my $copy2tmp = "cp -r $src_dir/* $tmp_dir";
    # 2. Workaround to add subdirectories as findable modules
    my $pdflatex = "cd $tmp_dir && TEXINPUTS=.//: pdflatex $src_base";
    # 3. Bibtex for bibliography
    my $bibtex = "cd $tmp_dir && bibtex $aux_file";
    # 4. 5. pdflatex, again!
    # 6. Move the generated file to base directory and hide all the nastiness :)
    my $move_cmd = "mv $tmp_file $dst";
    #
    # A regular pdf can simply skip step 2 and 3, haha!

    my @bibliography_cmds = (
        $copy2tmp,
        $pdflatex,
        $bibtex,
        $pdflatex,
        $pdflatex,
        $move_cmd);

    my @simple_cmds = (
        $copy2tmp,
        $pdflatex,
        $pdflatex,
        $move_cmd);

    my @cmds;
    if ($bibliography) { @cmds = @bibliography_cmds; }
    else { @cmds = @simple_cmds; }

    say "Generating $dst...";

    for my $cmd (@cmds) {
        ## Hide command output?
        $cmd = $cmd . " >/dev/null 2>&1" unless $verbose;
        run_cmd($cmd);
    }
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
  $name -v | --verbose
  $name -c | --clean
  $name --show_cmds

Options:
  -h --help     Show this screen.
  -v --verbose  Print runs of commands.
  -c --clean    Cleanup pdf files and temporary things.
  --show_cmds   Show the commands run, but not their output.
END

    exit;
}

sub clean_tmp {
    # Just a safeguard... :)
    if ($tmp_dir) {
        say "rm $tmp_dir/*" if $show_cmds;
        unlink glob "$tmp_dir/*";
    }
}

sub clean_pdfs {
    if ($base) {
        say "rm $base/*.pdf" if $show_cmds;
        unlink glob "$base/*.pdf";
    }
}

sub clean {
    clean_tmp();
    clean_pdfs();
    exit;
}

sub run_cmd {
    for my $cmd (@_) {
        say $cmd if $show_cmds;
        system($cmd) == 0 or die "system `$cmd` failed: $?";
    }
}
