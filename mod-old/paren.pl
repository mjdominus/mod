#!/usr/bin/perl

# Idea: To process nested parentheses, use this algorithm:
#  Seek from beginning to find the *first* close parenthesis
#  Seek backwards from this parenthesis to the first preceding open parenthesis
# Process the test between these parentheses.

sub handle_parens {
  my ($t, $code, $o, $c) = @_;
  $o = '(' unless defined $o;
  $c = ')' unless defined $c;

  while ('true') {
    print "--$t--\n";
    last if (my $cp = index  $t, $c)      < 0;
    last if (my $op = rindex $t, $o, $cp) < 0;
    $code->(substr($t, $op, $cp-$op+1));
  }

  return;
}


sub prelim {
  print "  >>", $_[0], "<<\n";
  $_[0] = '...';
}

# handle_parens("<this is a <test> of <<the> handler>>", \&prelim, '<', '>');
mod_escape("Any number has the form M<2k+b>, where M<b> is the final bit of the
binary expansion and is either 0 or 1.  It's easy to see whether this
final bit will be 0 or 1; just look to see if the input number is even
or odd.  The rest of the number is M<2k>, and that means that its
binary expansion is the same as for M<k>, but shifted left one place.
For example, the number M<37 = 2 * 18 + 1 \\> 6>; here M<k> is 18 and M<b>
is 1, so the binary expansion of 37 is the same as that for 18, but
with an extra 1 on the end.  And in fact the expansion for 37 is
100101 and for the binary expansion for 18 is 10010.", \&prelim);
