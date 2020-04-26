
package Mod::TeX;
use Mod::Generic;
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

sub extension () { 'tex' };

sub init {
  my $self = shift;
  my $chapno = $self->getparam('startchapter', 1)-1;
  qq{
\\input ms
\\parskip 8pt
\\chapno=$chapno
  };
}

sub fin {
  qq{
\\end
  };
}

sub tex_escape {
  my ($self, $text) = @_;
  $text =~ s/([#\$%&~_^\\{}])/\\$1/g;
  $text;
}

sub prose {
  my ($self, $text, @args) = @_;
  $text = $self->tex_escape($text);
  $text = $self->expand_escapes($text);
  my $indent = '';
  if ($self->{just_did_program}) {
    $indent = '\noindent ';
    $self->{just_did_program} = 0;
  }
  return "\n\n$indent$text";
}

sub whitespace {
  my ($self, $text, @args) = @_;
  return "\\par\n";
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
    s/^$prefix/    /;
#    $_ = $self->tex_escape($_);
    $_ =~ s/([\\{}])/\\$1/g;
  }

  for my $i (0 .. $#lines) {
    $lines[$i] = ($marked[$i] ? "\\ch " : "\\nc ") . $lines[$i];
  }
  $self->{just_did_program} = 1;

  join "\n", 
    "\\startlisting",
    @lines,
    "\\endlisting", "";
}

sub listing {
  my ($self, $tag, $text, $progname, @args) = @_;
  "";
}

sub inline {
  my ($self, $tag, $text, $progname, @args) = @_;
  my $PROGDIR = $self->{progdir};
  my $fh;
  unless (open $fh, "< $PROGDIR/$progname") {
    $self->warning("Couldn't inline program '$progname': $!; skipping");
    return "--- $progname ??? ---\n";
  }
  my $code;
  { local $/; $code = <$fh> }
  $self->program($code);
}

sub section {
  my ($self, $tag, $text, @args) = @_;
  $text = $self->expand_escapes($text);
  if ($tag eq 'chapter') {
    my $chapno = $self->getparam('startchapter', 1);
    return qq{\\chapter{$text}\n\n};
  } elsif ($tag eq 'section') {
    return qq{\\section{$text}\n\n};
  } elsif ($tag eq 'subsection') {
    return qq{\\subsection{$text}\n\n};
  } elsif ($tag eq 'subsubsection') {
    return qq{\\subsubsection{$text}\n\n};
  }
}

sub list {
  my ($self, $tag, $text, @args) = @_;
  my $listcontext = $self->{listcontext};
  $tag =~ s/(ed)?list$//;
  my $end = ($tag =~ s/^end//) ? 'end' : '';
  my $command = $tag =~ /bullet/ ? 'unorderedlist' : 'numberedlist';
  "\\$end$command\n"
}


sub listitem {
  my ($self, $tag, $text, @args) = @_;

  $text = $self->expand_escapes($text);
  "\\li $text\n\n";
}


# $prefix isn't supported yet.
sub indented {
  my ($self, $tag, $text, $prefix, @args) = @_;
  $text = $self->expand_escapes($text);
#  return "\\begin{quotation}\n$text\n\\end{quotation}\n\n";
  $text;
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
  $self->expand_escapes($main);
}

sub T_var {
  my ($self, $char, $text) = @_;
  "\$$text\$";
}

sub T_math {
  my ($self, $char, $text) = @_;
#  my $math = $self->{math};
#  my $repl = $math->{$text};
  qq{\$$text\$};
}

sub T_italics {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  "{\\it $text}";
}

sub T_bold {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  "{\\bf $text}";
}

sub T_code {
  my ($self, $char, $text) = @_;
#  $text = $self->tex_escape($text);
  "{\\tt $text}";
}

sub T_function {
  my ($self, $char, $text) = @_;
  $text = $self->expand_escapes($text);
  "{\\tt $text\()}";
}

sub T_footnote {
  my ($self, $char, $text) = @_;
  my $n = $self->{footnote}++;
  $text = $self->expand_escapes($text);
  return qq{\\footnote{$text}};
}

sub T_tag {
  my ($self, $char, $text) = @_;
  "{\tt <$text>}";
}

sub T_ref {
  my ($self, $char, $text) = @_;
  my (@items) = split /\|/, $text; 
  my $sectype = ucfirst lc pop @items;
  if ($sectype) {
    "$sectype ??";
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
This file is copyright &copy; 2002 Mark-Jason Dominus.  Unauthorized
distribution in any medium is absolutely forbidden.  
</font>

