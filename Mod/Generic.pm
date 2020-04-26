package Mod::Generic;
use strict;

sub new {
  my $pack = shift;
  no strict 'refs';
  my $self = { paragraph => \%{$pack . '::paragraph'},
               command => \%{$pack . '::command'},
               escape => \%{$pack . '::escape'},
               line => 1,
               char => 0,
             };
  bless $self => $pack;
  $self;
}

sub extension { "out" }

sub init { }
sub fin { }
sub header { "" }
sub footer { "" }

sub do_file {
  my ($self, $in, $out) = @_;
  my ($IN, $OUT);
  unless (open $IN, "< $in") {
    warn "Couldn't open < $in: $!; skipping.\n";
    next;
  }
  $self->{infilename} = $in;
  $self->open_output_file($in, $out);

  my ($result, $contents);
  $result = $self->header;
  { local $/;
    $contents = <$IN>;
  }
  $result .= $self->do_text($contents);
  $result .= $self->footer;
  $self->output($result);
  $self->output($self->fin);
}

sub open_output_file {
  my ($self, $in, $out) = @_;
  my $OUT;
  unless (defined $out) {
    $out = $self->filenamecvt($in, $self->extension);
  }
  unless (open $OUT, ">", $out) {
    warn "Couldn't open > $out: $!; skipping.\n";
    return;
  }
  $self->{outfilename} = $out;
  $self->{OUTFH} = $OUT;
}

sub filenamecvt {
  my ($self, $out, $ext) = @_;
  $out =~ s/.mod$/.$ext/ or $out .= ".$ext";
  $out;
}

sub output {
  my ($self, $text) = @_;
  my $OUT = $self->{OUTFH};
  print $OUT $text;
}

sub _type_token {
  return ['whitespace', undef, $_] unless /\S/;
  if (/^\=(\w+)\s*/) {
    my $command = $1;
    $command =~ tr/A-Z=/a-z/d;
    my $argtext = $_;
    $argtext =~ s/^\=(\w+)\s*//;
    my @args = ($command, split /\s+/, $argtext);
    return ['command', \@args, $_];
  } elsif (/^([ \t*].*\n?)+$/) { # Indented paragraph
    my $stars = /^\*/m ? ['stars'] : undef;
    return ['program', $stars, $_];
  } else {
    return ['prose', undef, $_];
  }
}

sub do_text {
  my ($self, $text) = @_;
  $self->init() unless $self->{Inited}++;
  my $toks = $self->tokenize($text);
  my $out = $self->do_tokens($toks);
  $self->fin() unless $self->{Finished}++;
  return $out;
}

sub tokenize {
  my ($self, $text) = @_;

  my @tokens = split /(^\s*|\n\s*\n)/, $text;
  @tokens = map _type_token($_), @tokens;
  my @t2;

  # Combine consecutive program token into single program token
  # also discard empty tokens
  for (my $i=0; $i < @tokens; $i++) {
    my $t = $tokens[$i];
    last unless defined $t;
    next if $t->[2] eq ''; 
    unless ($t->[0] eq 'program') {
      push @t2, $t;
      next;
    }

    # look ahead.  If there's more program text next
    # (possibly with intervening whitespace) then it (and any intervening space)
    # gets coalesced with this token.
    my $last_program_j;
    for (my $j = $i+1;
         $j < @tokens &&
         ($tokens[$j][0] eq 'program' || $tokens[$j][0] eq 'whitespace');
         $j++) {
      $last_program_j = $j if $tokens[$j][0] eq 'program';  #  XXX repeated code
    }

    for my $j ($i+1 .. $last_program_j) {
      $t->[1] ||= $tokens[$j][1];
      $t->[2] .=  $tokens[$j][2];
    }
    push @t2, $t;
    $i = $last_program_j if defined $last_program_j;
  }
  wantarray ? @t2 : \@t2;
}

sub do_tokens {
  my ($self, $tokens) = @_;
  my $result = '';

  for (@$tokens) {
    my ($toktype, $args, $text) = @$_;

    my ($output, %option) = $self->format_paragraph($toktype, $args, $text);
    $result .= $output if defined $output;

    $self->adjust_position($text);
    $self->{last_tok} = $_;

    last if $option{Stop};
  }
  return $result;
}

sub warning {
  my ($self, $msg) = @_;
  if (lc $msg eq 'diag') { 
    return; # or $msg = shift;
  }
  my $line = $self->{pline} + $self->{line};
  my $char = $self->{pchar} + $self->{char};
  print STDERR "*** ", $msg, " near line $line (char $char) of input.\n";
  $self->{WARNED} = 1;
}

sub warned { my $x = $_[0]{WARNED}; $_[0]{WARNED} = 0; return $x }

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

sub scrub_escapes {
  my ($self, $t, %OPT) = @_;
  $self->expand_escapes($t, %OPT, Scrub => 1);
}

sub expand_escapes {
  my ($self, $t, %OPT) = @_;
  my $o = $OPT{Open} || '<';
  my $c = $OPT{Close} || '>';

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
      $plaintext = $self->format_plaintext($plaintext);
      if ($depth == 0) {
        $transformed .= $plaintext;
      } else {
        $contents .= $plaintext;
      }
    }

    $self->adjust_par_position($plaintext);

    if ($start ne '') {
      $contents .= $start;
      if ($depth++ == 0) {
        ($code_type) = ($start =~ /([A-Z])/);
      }
      $self->adjust_par_position($start);
    } elsif ($end) {
      $contents .= $end;
      my ($cont2) = ($contents =~ /^..(.*).$/s);
      if (--$depth == 0) {
        if ($OPT{Scrub}) {
          $transformed .= $cont2;
        } else {
          $transformed .= $self->format_escape($code_type, $cont2);
        }
        $code_type = $contents = '';
      }
      if ($depth < 0) {
        $self->warning("Unmatched $c");
        $depth = 0;
      }
      $self->adjust_par_position($end);
    }
  }
  $transformed;
}

sub adjust_par_position {
  my ($self, $t) = @_;
  $self->{pline} += ($t =~ tr/\n//);
  $self->{pchar} += length $t;
}

sub adjust_position {
  my ($self, $t) = @_;
  $self->{line} += ($t =~ tr/\n//);
  $self->{char} += length $t;
  $self->{pline} = $self->{pchar} = 0;
}

# default method uses dispatch tables defined in the subclass
sub format_paragraph {
  my ($self, $ptype, $args, $text) = @_;

  if ($ptype eq 'command') {
    my ($command, @args) = @$args;
    my $code =
         $self->{command}{$command}  # specific handler for this command
      || $self->{paragraph}{$ptype}; # catchall command handler
    return $text unless defined $code;
    $text =~ s/^=\w+\s+//;
    return $code->($self, $command, $text, @args);
  } else {
    my $code = $self->{paragraph}{$ptype};
    return $text unless defined $code;
    return $code->($self, $text, @$args);
  }
}

# default method leaves regular prose text unchanged
sub format_plaintext {
  my ($self, $t) = @_;
  $t;
}

# default method uses dispatch tables defined in the subclass
sub format_escape {
  my ($self, $char, $text) = @_;
  my $code = $self->{escape}{$char};
  return $text unless defined $code;
  $code->($self, $char, $text);
}

1;

