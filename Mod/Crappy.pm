
package Mod::Crappy;
use Mod::Generic;
@ISA = 'Mod::Generic';

sub extension () { 'crap' };

sub format_paragraph {
  my ($self, $ptype, $args, $text) = @_;

  # default behavior:  expand escape sequences in prose,
  # return otherwise unchanged.  ignore all commands
  if ($ptype eq 'whitespace' || $ptype eq 'program') {
    return $text;
  } elsif ($ptype eq 'prose') {
    return $self->expand_escapes($text);
  } else {                      # command
    if ($args->[0] eq 'stop') {
      return ('', Stop => 1);
    } else {
      return;
    }
  }
}

sub format_escape {
  my ($self, $code, $text) = @_;

  # default behavior:  "X<foo>" expands to "foo"  for all X.
  # recursive expansions performed everywhere.

#  ($text) = ($text =~ /^..(.*).$/s);   # extract contents
  $text = $self->expand_escapes($text);
  $text =~ s/\\([\\<>])/$1/g;
  return $text;
}


1;
