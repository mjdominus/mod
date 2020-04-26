#!/usr/bin/perl

%ENTITY = (gt => '>', lt => '<');
# use vars 'Text::Wrap::columns';
use Text::Wrap;

# Match a string with balanced < and >.
my $item = 
  qr/
  (?{local $d = 0})
  (?:
   (?> [^<>]+ )
   |
   (< (?{++$d}))
   |
   (> (?(?{--$d < 0})(?!)))
  )*
  (?(?{$d!=0})(?!))
  /x;

$/ = "";
open TOC, "> toc" or die "Couldn't open toc for writing: $!";
for (qw($offset)) {
  tiefunc($_);
}

while (<>) {
  for (split /^\s*$/m) {
  my $newlines = chomp;
  if (s/^=(\w+)\s*//) {
    my $tag = lc $1;
    if ($tag eq 'endcomment') {
      unless ($COMMENT) {
	warn "Unmatched =endcomment at chunk $. byte $offset\n";
      }
      $COMMENT = 0;
      next;
    } elsif ($COMMENT) {
      next;
    } elsif ($tag eq 'comment') {
      $COMMENT = 1;
      next;
    } elsif ($tag =~ /end(\w+)list$/) {
      unless ($lists[-1][0] eq $1) {
	warn "$lists[-1][0]list ended with $ {1}list at chunk $. byte $offset.\n";
	next;
      }
      pop @lists;
    } elsif ($tag =~ /(\w+)list$/) {
      push @lists, [$1, 1];
    } elsif ($tag eq 'item') {
      deliver(listitem($_));
    } elsif ($tag =~ /head(\d+)/) {
      my $level = $1;
      print TOC "=entry $level $offset $_\n";
      deliver(header($level, $_));
    } elsif ($tag =~ /^section$/) {
      print TOC "=entry 1 $offset $_\n";
      deliver(header(1, $_));
    } elsif ($tag =~ /^subsection$/) {
      print TOC "=entry 2 $offset $_\n";
      deliver(header(2, $_));
    } elsif ($tag eq 'chapter') {
      my ($chapno, $chaptitle) = split /\s+/, $_, 2;
      print TOC "=chapter $chapno $offset $chaptitle\n";
      deliver(chapterheader($chapno, $chaptitle));
    } elsif ($tag eq 'listing' || $tag eq 'startlisting') {
      my $progname = $_;
      my $started;
      if (exists $closed_listings{$progname}) {
	warn "Duplicate listing $progname at $offset; began at $closed_listings{$progname}.\n";
      } elsif (! exists $open_listings{$progname}) {
	open "LISTING_$progname", "> $progname.pl" or die "$!";
	$open_listings{$progname} = $offset;
	$started = 1;
      }
      deliver(listingheader($progname, $started));
    } elsif ($tag eq 'endlisting') {
      my $progname = $_;
      close "LISTING_$progname";
      $closed_listings{$progname} = delete $open_listings{$progname};
      deliver(endlisting($progname));
    } elsif ($tag eq 'stop') {
      close ARGV;
    } else {
      warn "Unknown tag $tag.\n";
      deliver($_);
    }
  } elsif ($COMMENT) {
    next;
  } elsif (/^\*?(\t|\s{4})/) {
    foreach my $progname (keys %open_listings) {
      my $fh = "LISTING_$progname";
      print $fh $_;
    }
    deliver(program($_));
  } else {
    deliver(text($_));
  }
}
}

sub deliver {
  my ($text, %a) = @_;
  my @lines;
  if ($a{expand}) {
    $text = expand($text);
  }
  if ($a{nofill}) {
    @lines = split /\n/, $text, -1;
  } else {
    local $Text::Wrap::columns = $a{fillwidth} || 72;
    my $parindent = $a{parindent} || '';
    my $fillindent = $a{fillindent} || '';
    $text =~ tr/\n/ /;
    @lines = split /\n/, wrap($parindent, $fillindent, $text), -1;
    push @lines, '', '';
  }
  my @savedlines;
  if (@lines > $linesleft) {
    my @firstlines = splice(@lines, 0, $linesleft);
    @savedlines = @lines;
    @lines = @firstlines;
  }
  { local $, = "\n";
    print @lines;
    $linesleft -= @lines;
  }
  if (@savedlines) {
    newpage();
    local $, = "\n";
    print @savedlines;
    $linesleft -= @savedlines;
  }
}

sub expand {
  local ($_) = @_;
  # Also handle F<...> = footnotes here
  # Also handle M<...> = mathematics here
  for (;;) {
    my $p = $_;
    s/C<([^<>]*)>/\`$1\'/go;
    s/B<([^<>]*)>/*$1*/go;
    s/I<([^<>]*)>/_$1_/go;
    s/V<([^<>]*)>/M<$1>/go;  # Variable
    s/F<([^<>]*)>//go;  # Footnote
    s/M<([^<>]*)>/$1/g;  # Mathematics
    s/X<([^<>]*)>/mindex($1, pos())/geo;  # Index entry
    s/T\[([^]]*)\]/<$1>/g; # HTML tag
    last if $p eq $_;
    s/E\[(\w+)\]/$ENTITY{$1}/g;  # Index entry
  }
  s/Z<>//g;
  $_;
}

# options: 1 - first mention
# B - bold  I - italic  C - code  for PAGE NUMBER
# K<...> alphabetizing key
# T<...> text entry  (e.g, see also)
# i - include entry verbatim in running text
# d -definition (enables i, typesets in italics)
# f - function name  (enables i, typsets in code style)
# ( start   ) end
# 
sub mindex {
  my $txt = shift;
  $txt =~ s/\|.*//;
  return $txt;
}

sub text {
  my ($t) = @_;
  $t =~ s/^%%%.*\n//mg;
  if ($no_indent) {
    $no_indent = 0;
  } else {
    $pi = '    ' ;
  }
  ($t."\n\n", parindent => $pi, expand => 1);
}

sub header {
  my ($level, $head) = @_;
  if ($level == 1) {
    $head = center(uc $head);
  } elsif ($level == 2) {
    $head = center($head);
  } elsif ($level == 3) {
    $head = uc $head;
  } elsif ($level < 4) {
    die "Bad header level `$level' for header $head\n";
  }
  return ("\n\n$head\n\n", nofill => 1);
}

sub chapterheader {
  my ($chapno, $title) = @_;
  newpage();
  $no_indent = 1;
  $cur_chapno = $chapno;
  $cur_chapter = $title;
  ("\nCHAPTER $chapno:    $title\n\n\n\n", nofill => 1);
}

sub listingheader {
  "\n";
}

sub endlisting {
  "\n";
}

sub listitem {
  my ($t) = @_;
  my ($type, $num) = @{$lists[-1]};
  my $indent = '  ' x @lists;
  if ($type eq 'bulleted') {
    return $indent . ' * ' . $t;
  } elsif ($type eq 'numbered') {
    $lists[-1][1]++;
    return ($indent . sprintf("%2d. ", $num) . $t, fillindent => $indent . ' ');
  } else {
    warn "Unrecognized list item type `$type' at chunk $. byte $offset.\n";
    return "??? $t";
  }
}

sub newpage {
  $page++;
  $linesleft = 66;
}

sub program {
  $no_indent = 1;
  ($_[0]."\n\n", nofill => 1);
}

sub center {
  my ($s) = @_;
  (' ' x (36 - (length $s)/2)) . $s;
}


################################################################

sub offset {
  tell ARGV;
}


sub tiefunc {
  my ($var) = @_ or die;
  my ($sigil, $name) = $var =~ /(.)(.*)/;
  my $pkg = "TIES::$name";
  my $dummy = sub { my $x = 1; bless \$x => $pkg };
  *{$pkg . '::FETCH'} = \&{$name};
  if ($sigil eq '$') {
    *{$pkg . '::TIESCALAR'} = $dummy;
    tie $ {$name} => $pkg;
  } elsif ($sigil eq '@') {
    *{$pkg . '::TIEARRAY'} = $dummy;
    tie @ {$name} => $pkg;
  } elsif ($sigil eq '%') {
    *{$pkg . '::TIEHASH'} = $dummy;
    tie % {$name} => $pkg;
  } else {
    die "Unknown sigil '$sigil'.\n";
  }
}
