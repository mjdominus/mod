#!/usr/bin/perl -w

package Mod::Driver;
use Exporter;
@ISA = 'Exporter';
@EXPORT = qw(transform mod_escape);

sub import {
  my $pack = shift;
}

sub new {
  my $pack = shift;
  my $driver = shift;
  my $drivermod = "Mod::\u\L$driver";
  my $driverfile = "Mod/\u\L$driver.pm";
  unless ($INC{$driverfile}) {
    *{$drivermod . '::warning'} = \&warning;
    require $driverfile;
    $drivermod->import(@_);
  }
  my $self = { process => \%{$drivermod . '::process'},
               transform => \%{$drivermod . '::transform'},
               result => $driver,
             };
  bless $self => $pack;
}

sub filenamecvt {
  my ($self, $out) = @_;
  $out =~ s/.mod$/.txt/ or $out .= '.txt'; # FIX
  $out;
}

sub dofile {
  my ($self, $in, $out) = @_;
  local *FH;
  unless (open FH, "< $in") {
    warn "Couldn't open < $in: $!; skipping.\n";
    next;
  }
  my $contents;
  { local $/;
    $contents = <FH>;
  }


  unless (defined $out) {
    $out = $self->filenamecvt($in);
  }
  unless (open FH, "> $out") {
    warn "Couldn't open > $out: $!; skipping.\n";
    return;
  }

  if ($self->{process}{init}) {
    $self->{process}{init}->($self);
  }

  my @tokens = split /(\n\s*\n)/, $contents;
  my $last_tok = '';
 TOKEN:
  while (@tokens) {
    my ($toktype);
    my @args;
    local $_ = shift @tokens;
    if (! /\S/) {               # All whitespace
      $toktype = 'whitespace';
    } elsif (s/^\=(\w+)\s*//) {
      $toktype = $1;
      $toktype =~ tr/A-Z=/a-z/d;
      @args = split;
#      print ">> =$toktype directive.\n";
    } elsif (/^([ \t*].*\n?)+$/) { # Indented paragraph
      $toktype = 'program';
    } else {
      $toktype = 'paragraph';
    }

    my $code;
  RESOLVE_CODE:
    {
      $code = $self->{process}{$toktype} || $self->{process}{DEFAULT};
#      redo RESOLVE_CODE unless defined ref $code;
      unless (defined $code) {
        warn "Unrecognized code type `$toktype'; using null\n";
        $code = sub { return $_[1] };
      }
    }

    $LINE += tr/\n//;
    $CHAR += length;

    my ($output, %option) = $code->($toktype, $_, $last_tok, @args,);
    $last_tok = $toktype;

    if ($option{Stop}) {
      last TOKEN;
    }

    print FH $output if defined $output;
  }
}

sub dofile {
  my ($self, $in, $out) = @_;
  local *FH;
  unless (open FH, "< $in") {
    warn "Couldn't open < $in: $!; skipping.\n";
    next;
  }
  my $contents;
  { local $/;
    $contents = <FH>;
  }


  unless (defined $out) {
    $out = $self->filenamecvt($in);
  }
  unless (open FH, "> $out") {
    warn "Couldn't open > $out: $!; skipping.\n";
    return;
  }

  if ($self->{process}{init}) {
    $self->{process}{init}->($self);
  }

  my @tokens = split /(\n\s*\n)/, $contents;
  my $last_tok = '';
 TOKEN:
  while (@tokens) {
    my ($toktype);
    my @args;
    local $_ = shift @tokens;
    if (! /\S/) {               # All whitespace
      $toktype = 'whitespace';
    } elsif (s/^\=(\w+)\s*//) {
      $toktype = $1;
      $toktype =~ tr/A-Z=/a-z/d;
      @args = split;
#      print ">> =$toktype directive.\n";
    } elsif (/^([ \t*].*\n?)+$/) { # Indented paragraph
      $toktype = 'program';
    } else {
      $toktype = 'paragraph';
    }

    my $code;
  RESOLVE_CODE:
    {
      $code = $self->{process}{$toktype} || $self->{process}{DEFAULT};
#      redo RESOLVE_CODE unless defined ref $code;
      unless (defined $code) {
        warn "Unrecognized code type `$toktype'; using null\n";
        $code = sub { return $_[1] };
      }
    }

    $LINE += tr/\n//;
    $CHAR += length;

    my ($output, %option) = $code->($toktype, $_, $last_tok, @args,);
    $last_tok = $toktype;

    if ($option{Stop}) {
      last TOKEN;
    }

    print FH $output if defined $output;
  }
}


sub warning {
  my ($msg) = @_;
  if (lc $msg eq 'diag') { 
    return; # or $msg = shift;
  }
  print STDERR "*** ", $msg, " near line $LINE (char $CHAR) of input.\n";
}

sub setparam {
  my ($self, $key, $value) = @_;
  $self->{param}{$key} = $value;
}

sub getparam {
  my ($self, $key, $default) = @_;
  if (exists $self->{param}{$key}) {
    $self->{param}{$key};
  } else {
    $default;
  }
}

sub transform {
  my ($text) = @_;
  $text = mod_escape($text, \&dispatch_transformation);
  return $text;
}

# Seems to work OK.
sub mod_escape {
  my ($t, $code, $o, $c) = @_;
  $o = '<' unless defined $o;
  $c = '>' unless defined $c;

  my $tok_regex = qr/([A-Z]\Q$o\E)|((?<!\\)(?:\\\\)*\Q$c\E)/;
  my @toks = split $tok_regex, $t;
  my $transformed = '';
  my ($code_type, $contents) = ('', '');
  my $depth = 0;


  while (@toks) {
    my ($plaintext, $start, $end) = splice @toks, 0, 3;
    if ($start && $end) {
      die "GACK!  start and end both matched!\n";
    }
    if ($plaintext ne '') {
      if ($depth == 0) {
        $transformed .= $plaintext;
      } else {
        $contents .= $plaintext;
      }
    }
    if ($start ne '') {
      $contents .= $start;
      if ($depth++ == 0) {
        ($code_type) = ($start =~ /([A-Z])/);
      }
    } elsif ($end) {
      $contents .= $end;
      if (--$depth == 0) {
        $transformed .= $code->($contents);
        $code_type = $contents = '';
      }
    }
  }
  $transformed;
}



1;

