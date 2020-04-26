
package Mod::IndexTerms;
use Mod::Generic;
@ISA = 'Mod::Generic';

sub N { "" }

%paragraph = (
              'whitespace' => \&N,
              'prose' => \&prose,
              'program' => \&N,
              'command' => \&N,
             );

%command = 
  (
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
    'V' => \&N,
    'M' => \&N,
    'I' => \&N,
    'C' => \&N,
    'F' => \&N,
    'B' => \&N,
    'N' => \&N,
    'T' => \&N,
    'R' => \&N,
  );

################################################################

sub extension () { 'indexterms' };

sub init {
  my $self = shift;
  "";
}

sub fin { "" }

sub prose {
  my ($self, $text, @args) = @_;
  $self->expand_escapes($text);
  my @indexitems = @{$self->{index_items}};
  @{$self->{index_items}} = ();
  join "\n", @indexitems, "";
}

sub whitespace { "" }

sub program { "" }

sub Stop {
  return '', Stop => 1;
}

################################################################

# NOT FINISHED
sub T_index {
  my ($self, $char, $text) = @_;
  $text =~ tr/\n/ /;
  my @items = (split /\|/, $text);
  my $flags = "";
  if (@items > 1) { $flags = pop @items }
  return if $flags =~ /\)/;
  my $text = join " / ", @items;
  $text .= " [start of section]" if $flags =~ /\(/;
  $text .= " [definition]" if $flags =~ /d/;
  $text = "C<$text>" if $flags =~ /C/;
  $text = "I<$text>" if $flags =~ /I/;
  $text = "B<$text>" if $flags =~ /B/;
  $flags =~ tr/()CIBid//d;
  warn "Flags $flags\n" if $flags;
  push @{$self->{index_items}}, $text;
}

sub DESTROY {
  $self->SUPER::DESTROY;
}


1;

__DATA__
This work has been submitted to Morgan Kaufmann Publishers for
possible publication.  Copyright may be transferred without notice,
after which this version may no longer be accessible.

This file is copyright &copy; 2004 Mark-Jason Dominus.  Unauthorized
distribution in any medium is absolutely forbidden.




