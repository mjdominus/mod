#!/usr/bin/perl

$d = "SJKHAS";
my $item = qr/
  [A-Z]
  <
  [^<>]*
  >
  /x;

# $/ = "";
while (<DATA>) {
  chomp;
  for (;;) {
    my $old = $_;
    print $_, "\n";
    s/($item)/print "xx$1\n"/e;
    last if $old eq $_;
  }
  print "\n------\n";
}

__DATA__
B<foo>
A<fooo> B<bar>
A<fooB<bar>oooo>
