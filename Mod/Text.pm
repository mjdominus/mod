
package Mod::Text;
use Mod::Generic;
use Mod::Fill;
use DB_File;
use strict;
use vars qw(@ISA %paragraph %command %comment_table %escape);

@ISA = 'Mod::Generic';


sub ignore { $_[0]{suppress_following_space} = 1; "" }

%paragraph = (
              'whitespace' => \&whitespace,
              'prose' => \&prose,
              'program' => \&program,
             );

%command = 
  (
   'startlisting' => \&listing,
   'contlisting' => \&listing,
   'endlisting' => \&listing,
   'listing' => \&listing,
   'inline' => \&inline,

   'test' => \&test,
   'starttest' => \&test,
   'endtest' => \&test,
   'auxtest' => \&test,
   'testable' => \&test,
   'inline_testcode' => \&ignore,

   'startpicture' => \&caption,
   'endpicture' => sub {""},
   'picture' => \&caption,

   'chapter' => \&section,
   'section' => \&section,
   'subsection' => \&section,
   'subsubsection' => \&section,

   'note' => \&ignore,

   'bulletedlist' => \&list,
   'endbulletedlist' => \&list,
   'numberedlist' => \&list,
   'endnumberedlist' => \&list,
   'item' => \&listitem,

   'indented' => \&indented,
   'startmaxim' => \&indented,
   'endindented' => \&indented,
   'endmaxim' => \&indented,

   'stop' => \&Stop,
  );

%comment_table = 
  (
   'comment' => \&comment,
   'endcomment' => \&comment,
   'DEFAULT' => sub { '' },
  );

%escape = 
  ( 'X' => \&T_index,
    'V' => \&T_var,
    'M' => \&T_math,
    'I' => \&T_italics,
    'C' => \&T_code,
    'F' => \&T_function,
    'B' => \&T_bold,
    'N' => \&T_footnote,
    'T' => \&T_tag,
    'R' => \&T_ref,
  );


################################################################

sub extension () { 'txt' };

sub init {
  my $self = shift;
  my $chapno = $self->getparam('startchapter', 1);
  $self->{progdir} = $ENV{PROGDIR} || "Programs";
  $self->{comment} = 0;
  $self->{indentstr} = '  ';
  $self->{extra_indent} = '';
  $self->{prog_indent} = "    ";
  $self->{width} = 64;
  $self->{listcontext} = [];
  $self->{listing_handles} = {};
  my %math;
  unless (tie %math => "DB_File", "./mathescapes.txt.db", O_RDONLY, 0666, $DB_BTREE) {
    warn "Couldn't tie ./mathescapes: $!; ignoring math escapes\n";
    delete $escape{M};
  }
  $self->{math} = \%math;

  my @SECTIONS = qw(chapter section subsection subsubsection);
  $self->{section_order} = \@SECTIONS;
  for (0 .. $#SECTIONS) {
    $self->{section_order_reverse}{$SECTIONS[$_]} = $_;
  }

  my %SECNO;
  map { $SECNO{$_} = 0 } @SECTIONS;
  $self->{secno} = \%SECNO;
  $SECNO{$SECTIONS[0]} = $chapno-1;  # initial =chapter will increment this

  {
    my $mtcfile = $self->filenamecvt($self->{infilename}, 'mtc');
    open(my $toc, "> $mtcfile") ;  # or die?
    $self->{tocFH} = $toc;
  }
  tie my %ref => 'DB_File', "./xref.db", O_CREAT|O_RDWR, 0666, $DB_BTREE
    or die "Couldn't tie ./xref.db: $!; aborting";
  $self->{ref} = \%ref;
}

sub header { join '', <DATA> }

sub prose {
  my ($self, $text, @args) = @_;
  $text = $self->expand_escapes($text);
  $text = $self->indent($text);
#  $text = postprocess($text);  # Stupid
  return $text;
}

sub whitespace {
  my ($self, $text, @args) = @_;
  if ($self->{last_token}[0] eq 'whitespace'
      || $self->{suppress_following_space} || $self->{invisible}[0]) {
    $self->{suppress_following_space} = 0;
    return '';
  }
  "\n\n";
}

sub program {
  my ($self, $text, @args) = @_;
  $self->{suppress_following_space}=1, return "" if $self->{in_test};
  my $true_text = $text;
  my @marked = map 0+/^\*/, split /^/, $true_text;
  $true_text =~ s/^\t/        /mg;
  $true_text =~ s/^\*/ /mg;
  my $prefix = $self->{prefix}[0];
  unless (defined ($prefix)) {
    ($prefix) = ($true_text =~
                 m{\A(\ +).*      # First line with its prefix
                    (?:\n          # first line's newline
                     (?:\1.*\n     # subsequent lines, with same prefix
                       |\s*\n)*    #   or perhaps they're just empty
                     (?:\1.*\n?    # final line, possibly without trailer
                       |\s*$)      #   or perhaps it's just empty
                    )?             # there might be only one line
                    \z}x);
    $self->{prefix}[0] = $prefix
      if @{$self->{prefix}} && $self->{prefix}[0] eq "";
  }

  # Trim off prefix
  my @lines = split /^/, $true_text;
  {
    local $_;
    for (@lines) {
      s/^$prefix//;
    }
  }

  $true_text = $self->program_emit(\@lines, \@marked);

  return "" if $self->{invisible}[0];

  return $self->fixed_indent($true_text, $self->{prog_indent});
}

# get a list of program lines
# also a list of booleans that say that some are `marked'
# compute the actual appearance of the text 
# print it to all the open program handles
# return the text
sub program_emit {
  my ($self, $lines, $marked) = @_;

  # First save the true version of the text to the files
  my $text = join '', @$lines;

  for my $s (values %{$self->{listing_handles}}) {
    next unless defined $s && fileno $s;
    print $s $text, "\n";
  }

  # Now re-star all the marked lines and return the result.
  for my $i (0 .. $#$lines) {
    $lines->[$i] =~ s/^/   /;
    substr($lines->[$i], 0, 1) = '*' if $marked->[$i];
  }
  join '', @$lines;
}

sub test {
  my ($self, $tag, $text, $progname, @args) = @_;
  if ($tag eq 'endtest') {
    $self->{in_test} = 0;
  } elsif ($tag ne 'testable') {
    $self->{in_test} = 1;
  }
  $self->{suppress_following_space} = 1;
  "";
}

sub listing {
  my ($self, $tag, $text, $progname, @args) = @_;
  my $invisible = grep /invisible/, @args;
  my $noheader = grep /noheader/, @args;
#  my $trim = grep /trimmed/, @args;
  my $CONT = ($tag =~ /^cont/);
  my $listing_handles = $self->{listing_handles};
  $CONT = 0 unless exists $listing_handles->{$progname};
  my $PROGDIR = $self->{progdir};
  if ($tag eq 'listing' || $tag eq 'startlisting') {
    if (exists $listing_handles->{$progname}) {
      if (defined $listing_handles->{$progname}) {
        $self->warning("Opened listing for `$progname' while it was still open");
      } else {
        $self->warning("Opened listing for `$progname' a second time");
      }
      return '';
    }

    $self->{ref}{"Prog-$progname"} = $self->{ref}{"Prog-\u$progname"} = 
      $self->_section_number;
  }

  if ($tag eq 'listing' || $tag eq 'startlisting' || $tag eq 'contlisting') {
    my $fh;
    my $MODE = $CONT ? '>>' : '>';
    unless (open $fh, $MODE, "$PROGDIR/$progname") {
      $self->warning("Couldn't open $PROGDIR/$progname for writing: $!; skipping");
      return '';
    }
    $listing_handles->{$progname} = $fh;
    unless ($noheader) {
      my ($chap, @secs) = $self->_section_number;
      my $secno = join '.', @secs;
      print $fh "\n\n";
      print $fh "###\n### $progname\n###\n\n" unless $CONT;
      print $fh "## Chapter $chap section $secno\n\n";
    }
    unshift @{$self->{prefix}}, undef;
    push @{$self->{invisible}}, $invisible;
#    push @{$self->{trim_progs}}, $trim;
  } elsif ($tag eq 'endlisting') {
    shift @{$self->{prefix}};
    $self->{suppress_following_space} ||= pop @{$self->{invisible}};
#    pop @{$self->{trim_progs}};

    if (exists $listing_handles->{$progname}) {
      if (defined $listing_handles->{$progname}) {
        close $listing_handles->{$progname};
        undef $listing_handles->{$progname};
      } else {
        $self->warning("Closing listing for `$progname' a second time");
      }
      return;
    } else {
      $self->warning("Closing listing for `$progname' which was never opened");
    }
  } else {
    $self->warning("Unrecognized tag `$tag' in Mod::Text::listing");
  }
  return '';
}

sub inline {
  my ($self, $tag, $text, $progname, @args) = @_;
  my $PROGDIR = $self->{progdir};
  my $fh;
  unless (open $fh, "< $PROGDIR/$progname") {
    $self->warning("Couldn't inline program '$progname': $!; skipping");
    return "--- $progname ??? ---\n";
  }
  local $/;
  my $code = <$fh>;
  return $self->fixed_indent($code, "        ");
}

sub _section_number {
  my $self = shift;
  my @numbers;
  my $lev;
  my @SECTIONS = @{$self->{section_order}};
  my $SECNO = $self->{secno};
  for my $sec (@SECTIONS) {
    last if (my $n = $SECNO->{$sec}) == 0;
    push @numbers, $n;
  }
  return wantarray ? @numbers : join '.', @numbers;
}

sub _section_level {
  my $self = shift;
  for my $sec (reverse @{$self->{section_order}}) {
    return $sec if $self->{secno}{$sec} > 0;
  }
}

sub section {
  my ($self, $tag, $text, @args) = @_;
  my @SECTIONS = @{$self->{section_order}};
  my $SECNO = $self->{secno};
  my $s;
  for (my $i=0; $i<@SECTIONS; $i++) {
    if ($tag eq $SECTIONS[$i]) {
      $s = $i; last;
    }
  }
  unless (defined $s) {
    $self->warning("Unrecognized sectioning command =$tag");
    return;
  }

  ++$SECNO->{$SECTIONS[$s]};
  for (my $i=$s+1; $i<@SECTIONS; $i++) {
    $SECNO->{$SECTIONS[$i]} = 0;
  }

  my @numbers = $self->_section_number($s);
  my $secno = $self->_section_number($s);
  my $l = "$secno: $text";
  $l .= " " x (78 - length $l) ;
  print STDERR "$l\r";
  $self->{ref}{"\u\L$tag\E-$text"} = $secno;

  #  $text =~ s/^=\w+\s+\d+\s+//;
  #  $text = $self->format_escape($text);
  $self->write_toc($s, \@numbers, $text);
  $text = $self->expand_escapes($text);  # or maybe do this before write_toc
  if ($s == 0) {
    return $self->centered(uc $text);
  } elsif ($s == 1) {
    return sprintf "* %d.  %s", $numbers[1], uc $text;
  } elsif ($s == 2) {
    return sprintf "** %d.%d.   %s ", $numbers[1], $numbers[2], uc $text;
  } else {
    return $text;
  }
}

sub write_toc {
  my ($self, $level, $numbers, $text) = @_;
  my $fh =  $self->{tocFH};
  return unless fileno $fh;
  print $fh $level, " ", join('.', @$numbers), " ", $text, "\n";
}

sub list {
  my ($self, $tag, $text, @args) = @_;
  my $listcontext = $self->{listcontext};
  $tag =~ s/(ed)?list$//;
  my $end = ($tag =~ s/^end//);
  if ($end) {
    my $cur_level = $listcontext->[-1][0];  
    if ($cur_level eq $tag) {
      pop @$listcontext;
    } else {
      $self->warning("=$cur_level ended by =$tag.  Ignoring =$tag");
      return ;
    }
  } else {
    push @$listcontext, [$tag, 1];
  }
  '';
}

sub listitem {
  my ($self, $tag, $text, @args) = @_;
  my $listcontext = $self->{listcontext};
  my $depth = @$listcontext;

  if ($depth == 0) {
    $self->warning("List item outside of list");
    return;
  }

  my ($type, $num) = @{$listcontext->[-1]};

  my $bullet = '';
  if ($type eq 'bullet') {
    $bullet = (' * ', ' + ', ' o ', ' - ', ' . ')[($depth-1) % 5];
  } elsif ($type eq 'number') {
    $bullet = sprintf "%3d. ", $num;
  } else {
    $self->warning("Unknown bullet type `$type'");
    $bullet = ' ? ';
  }

  ++$listcontext->[-1][1];
  $bullet . $self->expand_escapes($text);
}


sub caption {
  my ($self, $tag, $text, @args) = @_;
  ++$self->{picture_number};
  $self->centered("figure $self->{secno}{chapter}.$self->{picture_number} ('$text')");
}

# $prefix isn't supported yet.
sub indented {
  my ($self, $tag, $text, $prefix, @args) = @_;
  $tag =~ s/^start//;
  if ($tag eq 'indented' || $tag eq 'maxim') {
    $self->{extra_indent} .= "\t";
    push @{$self->{indents}}, $tag;
  } elsif ($tag =~ /^end/) {
    my $prev_tag = "end" . pop(@{$self->{indents}});
    if ($prev_tag ne $tag) {
      $self->warning("=$tag unmatched");
      return;
    }
    chop $self->{extra_indent};
  }
  return '';
}

sub indent {
  my ($self, $text, $extra) = @_;
  my @listcontext = @{$self->{listcontext}};
  $extra = '' unless defined $extra;
  my $indent = join '',
    $extra,
      $self->{extra_indent},
        ($self->{indentstr} x @listcontext);
  my $result = $self->fill($text, $self->{width}, $indent);
}

sub fixed_indent {
  my ($self, $text, $extra) = @_;
  my @listcontext = @{$self->{listcontext}};
  $extra = '' unless defined $extra;
  my $indent = join '',
    $extra,
      $self->{extra_indent},
        ($self->{indentstr} x @listcontext);
  $text =~ s/^/$indent/gm;
  $text;
}

sub DESTROY {
  my $self = shift;
  if ($self->{badmath_count}) {
    my $escapes = $self->{badmath_count} == 1 ? "escape" : "escapes";
    warn "$self->{badmath_count} unknown math $escapes encountered\n";
  }
  $self->SUPER::DESTROY;
}

sub Stop {
  return '', Stop => 1;
}

################################################################

# NOT FINISHED
sub T_index {
  my ($self, $char, $text) = @_;
  my (@items) = split /\|/, $text;
  s/\*\*\*OR/||/g for @items;   # Unpleasant HACK
  my $flags = (@items == 1) ? '' : pop @items;
  return '' if $flags =~ /[i()]/;
  if ($flags =~ s/d//) {
    $items[0] =~  s/(.*)/I<$1>/;
    $flags .= 'I';
  } elsif ($flags =~ s/f//) {
    $items[0] =~  s/(.*)/C<$1>/;
    $flags .= 'B';
  } elsif ($flags =~ s/r//) {
    $items[0] =~  s/(.*)/I<$1>/;
  }
  my $main = shift @items;
  #  $self->warning("Index item `$main' in style [$flags]");
  $self->expand_escapes($main);
}

sub T_var {
  my ($self, $char, $text) = @_;
  "`$text'";
}

sub T_math {
  my ($self, $char, $text) = @_;
  my $math = $self->{math};
  $text =~ tr/\n/ /;
  my $repl = $math->{$text};
  return $repl if defined $repl;
  # $self->warning("Bad math escape `M<$text>'");
  $self->{badmath_count}++;
  unless (fileno $self->{badmath}) {
    open my $bad, ">> badmath.txt"
      or die "Couldn't open `badmath': $!; aborting";
    $self->{badmath} = $bad;
  }
  my $bad = $self->{badmath};
  print $bad "$text\0";
  $text;
}

sub T_italics {
  my ($self, $char, $text) = @_;
  $text = $self->scrub_escapes($text);
  "_$ {text}_";
}

sub T_bold {
  my ($self, $char, $text) = @_;
  $text = $self->scrub_escapes($text);
  "*$text*";
}

sub T_code {
  my ($self, $char, $text) = @_;
  $text =~ s/\\([\\<>])/$1/g;
  "'$text'";
}

sub T_function {
  my ($self, $char, $text) = @_;
  $text = $self->scrub_escapes($text);
  $text  . '()';
}

sub T_footnote {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  return "[[Footnote: $text]]";
  # ...
}

sub T_tag {
  my ($self, $char, $text) = @_;
  "<$text>";
}

sub T_ref {
  my ($self, $char, $text) = @_;

  my $n = my (@items) = split /\|/, $text;
  my ($label, $sectype) = @items;

  unless ($n == 2) {
    my $items = $n == 1 ? 'item' : 'items';
    $self->warning("R<> construction with $n $items");
    return "(some section or chapter)";
  }
  $label =~ tr/\n/ /;

  if (uc $sectype eq "HERE") {
    $self->{ref}{$label}  = $self->_section_number;
    return "";
  }

  my $sec_level = $self->{section_order_reverse}{lc $sectype};
  $sectype = ucfirst(lc $sectype);

  my $ref = $self->{ref}{$label} 
         || $self->{ref}{"\u$label"}
         || $self->{ref}{"\U$label"};
  unless (defined $ref) {
    for my $level (reverse $sec_level .. @{$self->{section_order}}) {
      $ref = $self->{ref}{"\u\L$self->{section_order}[$level]\E-$label"}
          || $self->{ref}{"\u\L$self->{section_order}[$level]\E-\u$label"}
          || $self->{ref}{"\u\L$self->{section_order}[$level]\E-\U$label"};
      last if defined $ref;
    }
  }

  $ref ||= $self->{ref}{"Prog-$label"}
       || $self->{ref}{"Prog-\u$label"}
       || $self->{ref}{"Prog-\U$label"};

  if (defined $ref) {
    my @numbers = split /\./, $ref;
    my $chapter = sprintf "chap%02d.html", $numbers[0];
    $ref = join ".", @numbers[0..$sec_level];
    return qq{$sectype $ref};
  } else {
    $self->warning("Unknown reference for $sectype \"$label\"");
    return "$sectype ???";
  }
}

sub centered {
  my ($self, $text) = @_;
  my $s = ' ' x (($self->{width} - length $text)/2);
  $s . $text;
}



1;

__DATA__
This work has been submitted to Morgan Kaufmann Publishers for
possible publication.  Copyright may be transferred without notice,
after which this version may no longer be accessible.

----------------------------------------------------------------

This file is copyright 2004 Mark Jason Dominus.  Unauthorized
distribution in any medium is absolutely forbidden.  

----------------------------------------------------------------


            H I G H E R   O R D E R   P E R L 



