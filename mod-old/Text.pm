
package Mod::Text;
use Mod::Driver;
use Mod::Fill;
use DB_File;

%main_table = 
  (
   'init' => \&init,

   'whitespace' => \&whitespace,
   'paragraph' => \&paragraph,
   'program' => \&program,

   'startlisting' => \&listing,
   'endlisting' => \&listing,
   'listing' => \&listing,
   'inline' => \&inline,

   'startpicture' => sub {""},
   'endpicture' => sub {""},
   'picture' => sub {""},

   'chapter' => \&section,
   'section' => \&section,
   'subsection' => \&section,
   'subsubsection' => \&section,

   'comment' => \&comment,
   'endcomment' => \&comment,
   'note' => sub { "" },

   'bulletedlist' => \&list,
   'endbulletedlist' => \&list,
   'numberedlist' => \&list,
   'endnumberedlist' => \&list,
   'item' => \&listitem,

   'indented' => \&indented,

   'stop' => \&Stop,
  );

%comment_table = 
  (
   'comment' => \&comment,
   'endcomment' => \&comment,
   'DEFAULT' => sub { '' },
  );

%process = %main_table;

%transform = 
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

sub init {
  my $self = shift;
  $PROGDIR = $ENV{PROGDIR} || 'Programs';
  $COMMENT = 0;
  $INDENTSTR = '  ';
  $EXTRA_INDENT = '';
  $WIDTH = 64;
  @SECTIONS = qw(chapter section subsection subsubsection);
  tie %math => DB_File, "./mathescapes", O_RDONLY, 0666, $DB_BTREE
    or die "Couldn't tie ./mathescapes: $!; aborting";
  map { $SECNO{$_} = 0 } @SECTIONS;
  my $chapno = $self->getparam('startchapter', 1);
  $SECNO{$SECTIONS[0]} = $chapno-1;  # initial =chapter will increment this
  open(TOC, sprintf("> chap%02d.toc", $chapno)) and $TOC = 1;
}

# CLEAN UP DEBUGGING VARIABLES
sub paragraph {
  my ($tag, $text, $last_tok, @args) = @_;
  $text = transform($text);
  $text = indent($text);
#  $text = postprocess($text);  # Stupid
  return $text;
}

sub whitespace {
  my ($tag, $text, $last_tok, @args) = @_;
  if ($last_tok eq 'program') {
    program_emit($text);
  }
  return $last_tok eq 'whitespace' ? '' : "\n\n";
}

# BUG here - this removes the marked lines!
sub program {
  my ($tag, $text, $last_tok, @args) = @_;
  my $true_text = $text;
  my @marked = map {s/^\*/ /} (split /^/, $true_text);
  $true_text =~ s/^\t/        /mg;  
  my ($prefix) = ($true_text =~  
                  m{\A(\ +).*      # First line with its prefix
                    (?:\n          # first line's newline
                     (?:\1.*\n)*   # subsequent lines, with same prefix
                     (?:\1.*\n?)   # final line, possibly without trailer
                    )?             # there might be only one line
                    \z}x);          
  my @lines = split /^/, $true_text;
  {
    local $_;
    for (@lines) {
      s/^$prefix//;
    }
  }

  my $true_text = program_emit(\@lines, \@marked);
  return fixed_indent($true_text, "        ");
}

# get a list of program lines
# also a list of booleans that say that some are `marked'
# compute the actual appearance of the text 
# print it to all the open program handles
# return the text
sub program_emit {
  my ($lines, $marked) = @_;
  for my $i (0 .. $#$lines) {
    $lines->[$i] =~ s/^ /*/ if $marked->[$i];
  }
  my $text = join '', @$lines;
  for my $s (values %listing_handles) {
    next unless defined $s;
    my $fh = $s->{fh};
    print $fh $text;
  }
  $text;
}

sub listing {
  my ($tag, $text, $last_tok, $progname, @args) = @_;
  if ($tag eq 'listing' || $tag eq 'startlisting') {
    if (exists $listing_handles{$progname}) {
      if (defined $listing_handles{$progname}) {
        warning("Opened listing for `$progname' while it was still open");
      } else {
        warning("Opened listing for `$progname' a second time");
      }
      return '';
    }
    
    my $fh = \do{local *FH};
    unless (open $fh, "> $PROGDIR/$progname") {
      warning("Couldn't open $PROGDIR/$progname for writing: $!; skipping");
      return '';
    }
    $listing_handles{$progname} = {fh => $fh};
  } elsif ($tag eq 'endlisting') {
    if (exists $listing_handles{$progname}) {
      if (defined $listing_handles{$progname}) {
        close $listing_handles{$progname}{fh};
        undef $listing_handles{$progname};
      } else {
        warning("Closing listing for `$progname' a second time");
      }
      return;
    } else {
      warning("Closing listing for `$progname' which was never opened");
    }
  } else {
    warning("Unrecognized tag `$tag' in Mod::Text::listing");
  }
  return '';
}

sub inline {
  my ($tag, $text, $last_tok, $progname, @args) = @_;
  unless (open my $fh, "< $PROGDIR/$progname") {
    warning("Couldn't inline program '$progname': $!; skipping");
    return "--- $progname ??? ---\n";
  }
  local $/;
  my $code = <$fh>;
  return $code;
}

sub section {
  my ($tag, $text, $last_tok, @args) = @_;
  my $s;
  for (my $i=0; $i<@SECTIONS; $i++) {
    if ($tag eq $SECTIONS[$i]) {
      $s = $i; last;
    }
  }
  unless (defined $s) {
    warning("Unrecognized sectioning command =$tag");
    return;
  }

  ++$SECNO{$SECTIONS[$s]};
  my @numbers = @SECNO{@SECTIONS[0..$s]};
  { my $secno = join '.', @numbers;
    my $spc = '  ' x (@numbers-1);
    print STDERR "$spc$secno: $text\n";
  }
  for (my $i=$s+1; $i<@SECTIONS; $i++) {
    $SECNO{$SECTIONS[$i]} = 0;
  }

  $text =~ s/^=\w+\s+\d+\s+//;
  write_toc($s, \@numbers, $text);
  if ($s == 0) {
    return centered(uc $text);
  } elsif ($s == 1) {
    return sprintf "** %3d. %s", $numbers[1], uc $text;
  } elsif ($s == 2) {
    return sprintf "* %3d.%d %s", $numbers[1], $numbers[2], uc $text;
  } else {
    return $text;
  }
}

sub write_toc {
  return unless $TOC;
  my ($level, $numbers, $text) = @_;
  print TOC $level, " ", join('.', @$numbers), " ", $text, "\n";
}

sub comment {
  my ($tag, $text, $last_tok, @args) = @_;
  if ($tag eq 'comment' || $tag eq 'begincomment') {
    if ($COMMENT) {
      warning("=$tag directive inside of comment");
    }
    $COMMENT = 1;
    %process = %comment_table;
  } elsif ($tag eq 'endcomment') {
    unless ($COMMENT) {
      warning("=$tag directive not inside of comment");
      return;
    }
    $COMMENT = 0;
    %process = %main_table;
  } else {
    warning("Unrecognized tag `$tag' in Mod::Text::comment");
  }
  return;
}

sub list {
  my ($tag, $text, $last_tok, @args) = @_;
  $tag =~ s/(ed)?list$//;
  my $end = ($tag =~ s/^end//);
  if ($end) {
    my $cur_level = $listcontext[-1][0];
    if ($cur_level eq $tag) {
      pop @listcontext;
    } else {
      warning("=$cur_level ended by =$tag.  Ignoring =$tag");
      return ;
    }
  } else {
    push @listcontext, [$tag, 1];
  }
  '';
}

sub listitem {
  my ($tag, $text, $last_tok, @args) = @_;
  my $depth = @listcontext;

  if ($depth == 0) {
    warning("List item outside of list");
    return;
  }

  my ($type, $num) = @{$listcontext[-1]};

  my $bullet = '';
  if ($type eq 'bullet') {
    $bullet = (' * ', ' + ', ' o ', ' - ', ' . ')[($depth-1) % 5];
  } elsif ($type eq 'number') {
    $bullet = sprintf "%3d. ", $num;
  } else {
    warning("Unknown bullet type `$type'");
    $bullet = ' ? ';
  }

  ++$listcontext[-1][1];
  $bullet . transform($text);
}


sub indented {
  my ($tag, $text, $last_tok, $prefix, @args) = @_;
  if ($tag eq 'indented') {
    $EXTRA_INDENT .= "\t";
  } elsif ($tag eq 'endindented') {
    if ($EXTRA_INDENT eq '') {
      warning("=$tag unmatched");
      return;
    } 
    chop $EXTRA_INDENT;
  }
  return '';
}

sub indent {
  my ($text, $extra) = @_;
  $extra = '' unless defined $extra;
  my $indent = $extra . $EXTRA_INDENT . ($INDENTSTR x @listcontext);
  my $result = fill($text, $WIDTH, $indent);
}

sub fixed_indent {
  my ($text, $extra) = @_;
  $extra = '' unless defined $extra;
  my $indent = $extra . $EXTRA_INDENT . ($INDENTSTR x @listcontext);
  $text =~ s/^/$indent/gm;
  $text;
}

sub Stop {
  return '', Stop => 1;
}

################################################################

sub postprocess {
  my ($text) = @_;
  $text =~ s/T\[(\w+)\]/<$1>/;
  $text;
}


sub dispatch_transformation {
  my ($e, $t) = ($_[0] =~ /^(.)<(.*)>$/s);
  die "Couldn't disassemble escape code $_[0]"
    unless defined $t;
  
  my $code = $transform{$e};
  unless (defined $code) {
    warning("Unrecognized $e<...> escape; using null code");
    return "???<$t>???";
    return;
  }
  $code->($t);
}

sub T_ref { 
  my (@items) = split /\|/, $_[0]; 
  my $sectype = ucfirst lc pop @items;
  if ($sectype) {
    "$sectype ???";
  } else {
    warning("Empty R<> construction");
    "(some section ot chapter)";
  }
}

# NOT FINISHED
sub T_index {
  my ($text) = @_;
  my (@items) = split /\|/, $text;
  s/\*\*\*OR/||/g for @items;
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
#  warning("Index item `$main' in style [$flags]");
  $_[0] = $main;
}

sub T_var {
  my ($text) = @_;
  "`$text'";
}

my $badmath_open;
sub T_math {
  my ($text) = @_;
  my $repl = $math{$text};
  return $repl if defined $repl;
  unless ($badmath_open) {
    warning("Bad math escape `M<$text>'");
    open BADMATH, ">> badmath"
      or die "Couldn't open `badmath': $!; aborting";
    $badmath_open = 1;
  }
  print BADMATH "$text\n";
}

sub T_italics {
  my ($text) = @_;
  "_$ {text}_";
}

sub T_bold {
  my ($text) = @_;
  "*$text*";
}

sub T_code {
  my ($text) = @_;
  $text;
}

sub T_function {
  my ($text) = @_;
  $text  . '()';
}

sub T_footnote {
  my ($text) = @_;
  "[[Footnote: $text]]";
  # ...
}

sub T_tag {
  my ($text) = @_;
  "<$text>";
}

sub centered {
  my ($text) = @_;
  my $s = ' ' x (($WIDTH - length $text)/2);
  $s . $text;
}

1;

