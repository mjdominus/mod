
package Mod::Text;
use Mod::Generic;
use Mod::Fill;
use DB_File;
use strict;
use vars qw(@ISA %paragraph %command %comment_table %escape);

@ISA = 'Mod::Generic';



%paragraph = (
              'whitespace' => \&whitespace,
              'prose' => \&prose,
              'program' => \&program,
             );

%command = 
  (
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

   'note' => sub { $_[0]{suppress_following_space} = 1; "" },

   'bulletedlist' => \&list,
   'endbulletedlist' => \&list,
   'numberedlist' => \&list,
   'endnumberedlist' => \&list,
   'item' => \&listitem,

   'indented' => \&indented,
   'maxim' => \&indented,
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
  tie my %math => 'DB_File', "./mathescapes", O_RDONLY, 0666, $DB_BTREE
    or die "Couldn't tie ./mathescapes: $!; aborting";
  $self->{math} = \%math;
  my @SECTIONS = qw(chapter section subsection subsubsection);
  $self->{section_order} = \@SECTIONS;
  my %SECNO;
  map { $SECNO{$_} = 0 } @SECTIONS;
  $self->{secno} = \%SECNO;
  $SECNO{$SECTIONS[0]} = $chapno-1;  # initial =chapter will increment this
  {
    my $mtcfile = $self->filenamecvt($self->{infilename}, 'mtc');
    open(my $toc, "> $mtcfile") ;  # or die?
    $self->{tocFH} = $toc;
  }
  join '', <DATA>;
}

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
      || $self->{suppress_following_space}) {
    $self->{suppress_following_space} = 0;
    return '';
  }
  "\n\n";
}
sub program {
  my ($self, $text, @args) = @_;
  my $true_text = $text;
  my @marked = map 0+/^\*/, split /^/, $true_text;
  $true_text =~ s/^\t/        /mg;
  $true_text =~ s/^\*/ /mg;
  my ($prefix) = ($true_text =~  
                  m{\A(\ +).*      # First line with its prefix
                    (?:\n          # first line's newline
                     (?:\1.*\n     # subsequent lines, with same prefix
                       |\s*\n)*    #   or perhaps they're just empty
                     (?:\1.*\n?    # final line, possibly without trailer
                       |\s*$)      #   or perhaps it's just empty
                    )?             # there might be only one line
                    \z}x);

  # Trim off prefix
  my @lines = split /^/, $true_text;
  {
    local $_;
    for (@lines) {
      s/^$prefix//;
    }
  }

  $true_text = $self->program_emit(\@lines, \@marked);

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
    next unless fileno $s;
    print $s "\n", $text;
  }

  # Now re-star all the marked lines and return the result.
  for my $i (0 .. $#$lines) {
    $lines->[$i] =~ s/^/   /;
    substr($lines->[$i], 0, 1) = '*' if $marked->[$i];
  }
  join '', @$lines;
}

sub listing {
  my ($self, $tag, $text, $progname, @args) = @_;
  my $listing_handles = $self->{listing_handles};
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

    my $fh;
    unless (open $fh, "> $PROGDIR/$progname") {
      $self->warning("Couldn't open $PROGDIR/$progname for writing: $!; skipping");
      return '';
    }
    $listing_handles->{$progname} = $fh;
    my ($chap, @secs) = $self->_section_number;
    my $secno = join '.', @secs;
    print $fh "# Chapter $chap section $secno\n# $progname\n\n";
  } elsif ($tag eq 'endlisting') {
    if (exists $listing_handles->{$progname}) {
      if (defined $listing_handles->{$progname}) {
        close $listing_handles->{$progname};
        delete $listing_handles->{$progname};
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
  { my $secno = $self->_section_number($s);
    my $l = "$secno: $text";
    $l .= " " x (78 - length $l) ;
    print STDERR "$l\r";
  }

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


# $prefix isn't supported yet.
sub indented {
  my ($self, $tag, $text, $prefix, @args) = @_;
  if ($tag eq 'indented') {
    $self->{extra_indent} .= "\t";
  } elsif ($tag =~ /^end/) {
    if ($self->{extra_indent} eq '') {
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
  my $repl = $math->{$text};
  return $repl if defined $repl;
  unless (fileno $self->{badmath}) {
    $self->warning("Bad math escape `M<$text>'");
    open my $bad, ">> badmath"
      or die "Couldn't open `badmath': $!; aborting";
    $self->{badmath} = $bad;
  }
  my $bad = $self->{badmath};
  print $bad "$text\n";
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
  my (@items) = split /\|/, $text; 
  my $sectype = ucfirst lc pop @items;
  if ($sectype) {
    "$sectype ???";
  } else {
    $self->warning("Empty R<> construction");
    "(some section or chapter)";
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

This file is copyright 2001 Mark-Jason Dominus.  Unauthorized
distribution in any medium is absolutely forbidden.  

----------------------------------------------------------------


  P E R L   A D V A N C E D   T E C H N I Q U E S   H A N D B O O K



