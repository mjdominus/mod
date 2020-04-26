
package Mod::HTML;
use Mod::Generic;
use Mod::Fill;
use DB_File;
@ISA = 'Mod::Generic';



%paragraph = (
              'whitespace' => \&whitespace,
              'prose' => \&prose,
              'program' => \&program,
             );

%command = 
  (
   'startlisting' => \&listing,
   'endlisting' => sub {""},
   'listing' => \&listing,
   'inline' => \&inline,

   'startpicture' => sub {""},
   'endpicture' => sub {""},
   'picture' => sub {""},

   'chapter' => \&section,
   'section' => \&section,
   'subsection' => \&section,
   'subsubsection' => \&section,

   'note' => sub { "" },

   'bulletedlist' => \&list,
   'endbulletedlist' => \&list,
   'numberedlist' => \&list,
   'endnumberedlist' => \&list,
   'item' => \&listitem,

   'indented' => \&indented,
   'endindented' => \&indented,
   'maxim' => \&indented,

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

%HTML_escape = ('<' => 'lt', '>' => 'gt',
                '"' => 'quot', '&' => 'amp',
               );

################################################################

sub extension () { 'html' };

sub html_escape {
  my ($self, $text) = @_;
  $text =~ s/([<>"&])/&$HTML_escape{$1};/g;
  $text;
}

sub init {
  my $self = shift;
  my $chapno = $self->getparam('startchapter', 1);
  $self->{current_section_numbers} = [$chapno+0];
  $self->{progdir} = $ENV{PROGDIR} || "Programs";
  tie my %math => DB_File, "./mathescapes", O_RDONLY, 0666, $DB_BTREE
    or die "Couldn't tie ./mathescapes: $!; aborting";
  $self->{math} = \%math;
  my @SECTIONS = qw(chapter section subsection subsubsection);
  $self->{section_order} = \@SECTIONS;

  my $toc;
  {
    my $tocname = $self->filenamecvt($self->{infilename}, 'toc');
    $tocname =~ s/\.toc/-html.toc/;
    $toc = $self->loadtoc($tocname);
    open(my $tocFH, "> $tocname");
    $self->{tocFH} = $tocFH;
  }

  $self->{index} = $self->{footnote} = 1;
  $self->{footnotes} = [];
  $self->{maxchapter} = 5;
  join "", <DATA>, $toc;
}

sub loadtoc {
  my ($self, $file) = @_;
  my $cur_level = 0;
  open my $toc, "< $file" or return "";
  my $html = '';
  while (<$toc>) {
    chomp;
    my ($nums, $text) = split /\s+/, $_, 2;
    my @nums = split /\./, $nums;
    my $level = @nums-1;
    next unless $level > 0;

    $#nums = $level;
    my $anchor = "section-$nums";
    if ($level > $cur_level) {
      $html .= "<ol>" x ($level - $cur_level) . "\n";
    } elsif ($level < $cur_level) {
      $html .= "</ol>" x ($cur_level - $level) . "\n";
    }

    $html .= qq{<li><a href="#$anchor">$text</a>\n};
    $cur_level = $level;
  }
  $html .= "</ol>" x $cur_level . "\n";
  qq{<hr>\n<font size="-1">$html\n</font>\n<hr>};
}



sub fin {
  my $self = shift;

  my $fin = '';
  if (@{$self->{footnotes}}) {
    $fin .= "\n<hr>\n";
    $fin .= join "\n\n", @{$self->{footnotes}};
    $fin .= "\n\n\n\n";
  }
  $fin .= "<hr>\n\n";
  my $cn = $self->getparam('startchapter');
  my ($p, $n) = ($cn-1, $cn+1);
  my @links;
  if ($p > 0) {
    push @links, sprintf qq{<a href="chap%02d.html">Chapter %d</a>}, $p, $p;
  }
  if ($n <= $maxchapter) {
    push @links, sprintf qq{<a href="chap%02d.html">Chapter %d</a>}, $n, $n;
  }
  push @links, qq{<a href="PATH.html">TOP</a>};
  $fin .= join " | ", @links;
  $fin .=  "\n\n</body></html>\n";
  return $fin;
}

sub prose {
  my ($self, $text, @args) = @_;
  $text = $self->expand_escapes($text);
#  $text = $self->html_escape($text);
  return "<P>$text</P>\n\n";
}

sub whitespace {
  my ($self, $text, @args) = @_;
  return;
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
  chomp @lines;
  for (@lines) {
    s/^$prefix/        /;
    $_ = $self->html_escape($_);
  }

  for my $i (0 .. $#lines) {
    $lines[$i] = "<font color=purple><b>$lines[$i]</b></font>" if $marked[$i];
  }

  join "\n", "<pre>", @lines, "</pre>", "";
}

sub listing {
  my ($self, $tag, $text, $progname, @args) = @_;
  qq{<p><font size="-1"><a href="$self->{progdir}/$progname">Download code for <tt>$progname</tt></a></font></p>};
}

sub inline {
  my ($self, $tag, $text, $progname, @args) = @_;
  my $PROGDIR = $self->{progdir};
  my $fh;
  unless (open $fh, "< $PROGDIR/$progname") {
    $self->warning("Couldn't inline program '$progname': $!; skipping");
    return "--- $progname ??? ---\n";
  }
  my @code = <$fh>;
  chomp @code;
  for (@code) {
    s/^/        /;
    $_ = $self->html_escape($_);
  }
  return join "\n", "<pre>", @code, "</pre>", "\n";
}

sub section {
  my ($self, $tag, $text, @args) = @_;
  my @SECTIONS = @{$self->{section_order}};
  my $nums = $self->{current_section_numbers};
  my $level;

  for (my $i=0; $i<@SECTIONS; $i++) {
    if ($tag eq $SECTIONS[$i]) {
      $level = $i; last;
    }
  }
  if ($level) {
    $#$nums = $level;
    $nums->[$level]++;
  }
  my $n = join '.', @$nums;

  $text = $self->expand_escapes($text);
  {
    my $toc = $self->{tocFH};
    print $toc "$n $text\n";
  }
  { my $l = "$n: $text";
    $l .= " " x (78 - length $l) ;
    print STDERR "$l\r";
  }
  my $h = $level + 1;
  $text = qq{<a name="section-$n">$text</a>} if $level;
  qq{<h$h>$text</h$h>\n\n};
}

sub list {
  my ($self, $tag, $text, @args) = @_;
  my $listcontext = $self->{listcontext};
  $tag =~ s/(ed)?list$//;
  my $end = ($tag =~ s/^end//) ? '/' : '';
  my $ol = $tag =~ /bullet/ ? 'ul' : 'ol';

  "<$end$ol>\n";
}

sub listitem {
  my ($self, $tag, $text, @args) = @_;

  $text = $self->expand_escapes($text);
  "<li>$text\n";
}


# $prefix isn't supported yet.
sub indented {
  my ($self, $tag, $text, $prefix, @args) = @_;
  return $tag eq 'endindented' ? "</blockquote>\n" : "<blockquote>\n";
#  $text = $self->expand_escapes($text);
#  return "<blockquote>\n$text\n</blockquote>\n\n";
}

sub Stop {
  return '', Stop => 1;
}

################################################################

# NOT FINISHED
sub T_index {
  my ($self, $char, $text) = @_;
  my $n = $self->{index}++;
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
  qq{<a name="index-$n">} . $self->expand_escapes($main) . "</a>";
}

sub T_var {
  my ($self, $char, $text) = @_;
  "<var>$text</var>";
}

sub T_math {
  my ($self, $char, $text) = @_;
  my $math = $self->{math};
  my $repl = $math->{$text};
  return $self->html_escape($repl) if defined $repl;
  unless (fileno $self->{badmath}) {
    $self->warning("Bad math escape `M<$text>'");
    open my $bad, ">> badmath"
      or die "Couldn't open `badmath': $!; aborting";
    $self->{badmath} = $bad;
  }
  my $bad = $self->{badmath};
  print $bad "$text\n";
  return $self->html_escape($text);
}

sub T_italics {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  "<i>$text</i>";
}

sub T_bold {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  "<b>$text</b>";
}

sub T_code {
  my ($self, $char, $text) = @_;
  $text =~ s/\\([\\<>])/$1/g;
  $text = $self->html_escape($text);
  "<tt>$text</tt>";
}

sub T_function {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  "<tt>$text()</tt>";
}

sub T_footnote {
  my ($self, $char, $text) = @_;
  my $n = $self->{footnote}++;
  $text = $self->expand_escapes($text);
  push @{$self->{footnotes}}, 
    qq{<p><a name="footnote-$n">[$n] $text</a></p>};
  return qq{ <a href="#footnote-$n">[$n]</a>};
}

sub T_tag {
  my ($self, $char, $text) = @_;
  "<tt>&lt;$text&gt;</tt>";
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


1;

__DATA__
<html>
<head><title>Perl Advanced Techniques Handbook</title></head>

<body bgcolor="white">
<font size="+3">
This work has been submitted to Morgan Kaufmann Publishers for
possible publication.  Copyright may be transferred without notice,
after which this version may no longer be accessible.
</font>

<hr>

<font size="+3">
This file is copyright &copy; 2001 Mark-Jason Dominus.  Unauthorized
distribution in any medium is absolutely forbidden.  
</font>

