#!/usr/bin/perl

use Getopt::Std;
use Text::Abbrev;
getopts('c:o:') or die "Usage: $0 -o output-type [-c chapno] files...\n";
unless ($opt_o) {
  my $o = abbrev qw(text crappy html generic TeX);
  if ($0 =~ /.*\bm2(\w+)$/) {
    $opt_o = $o->{$1};
    if ($opt_o eq 'html') { $opt_o = 'HTML' }
  }
}
output_usage() unless $opt_o;

my $modulefile = "Mod/\u$opt_o.pm";
my $module = "Mod::\u$opt_o";
output_usage($@) 
  unless eval { require $modulefile; 
                $module->import() if defined &{"$module\::import"};
                1
              };

my $guess_chapnos = ! defined ${"opt_c"};
my $next_chapno = ${"opt_c"} || 1;

my $driver = $module->new('text')
  or die "Couldn't create driver for text: $!; aborting.\n";

for my $file (@ARGV) {
  if ($guess_chapnos && $file =~ /(\d+)\.mod$/) {
    $driver->setparam('startchapter', $1);
  } else {
    $driver->setparam('startchapter', $next_chapno++);
  }

  $driver->do_file($file);
}



################################################################

sub output_usage {
  my $msg = shift;
  print STDERR ">> $msg\n\n" if defined $msg;
  print STDERR <<EOM;
Legal values for -o option:
  Crappy - Trivial conversion to plain text; ignores all commands
  Text   - Plain text output
  HTML   - HTML output (unimplemented)
  TeX    - TeX output (unimplemented)
  test   - Extract and write out test files
EOM
  exit 1;
}
