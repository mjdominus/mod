#!/usr/bin/perl

# Idea: To process nested parentheses, use this algorithm:
#  Seek from beginning to find the *first* close parenthesis
#  Seek backwards from this parenthesis to the first preceding open parenthesis
# Process the test between these parentheses.

sub mod_escape {
  my ($t, $code, $o, $c) = @_;
  $o = '<' unless defined $o;
  $c = '>' unless defined $c;

  while ('true') {
    print "--$t--\n";
    my ($cp, $op);
    my $curs = 0;
    my $backslashes;
    do {
      $backslashes = 0;
      $cp = index  $t, $c, $curs;
      last if $cp < 0;
      $curs = $cp+1;
      # Odd number of backslashes means the > is escaped
      ++$backslashes while substr($t, $cp-1-$backslashes, 1) eq '\\';
    } while ($backslashes % 2 == 1);
    # $cp is now the index of the first unescaped )
    last if $cp < 0;

    $curs = $cp - 1;
    do {
      $op = rindex  $t, $o, $curs;
      $curs = $op-1;
    } while ($op >= 1 && substr($t, $op-1, 1) !~ /[A-Z]/);
    # $cp is now the index of the first preceding ( that has a tag
    last if $op < 1;

    my $tagged_section = substr($t, $op-1, $cp-$op+2);
    $tagged_section =~ s/\\</</g;
    $tagged_section =~ s/\\>/>/g;
    substr($t, $op-1, $cp-$op+2) = $code->($tagged_section);
  }

  return $t;
}


sub prelim {
  print "  >>", $_[0], "<<\n";
  $_[0];
}

# handle_parens("<this is a <test> of <<the> handler>>", \&prelim, '<', '>');
# mod_escape("foo X<4 \\< 3> bar", \&prelim);
mod_escape(qq{
to C<example(A =\\> 32, C =\\> 99)> must produce the same result as a call
to C<example(C =\\> 99, A =\\> 32)>, but the cache manager doesn't know
that, because the argument lists are superficially different.  If we
can arrange that equivalent argument lists are transformed to the same
hash key, the cache manager will return the same value for C<example(C
=\\> 99, A =\\> 32)> that it had previously computed for C<example(A =\\>
32, C =\\> 99)>, without the redundant call to C<example>.  This will
increase the cache hit rate M<h> in the formula M<hf - K> that
expresses the speedup from memoization.  The following key generator
does the trick:
}, \&prelim);
__END__
mod_escape("foo X<4 \\> 3> bar", \&prelim);
mod_escape("foo X<\\\\> bar", \&prelim);
mod_escape("Any number has the form M<2k+b>, where M<b> is the final bit of the
binary expansion and is either 0 or 1.  It's easy to see whether this
final bit will be 0 or 1; just look to see if the input number is even
or odd.  The rest of the number is M<2k>, and that means that its
binary expansion is the same as for M<k>, but shifted left one place.
For example, the number M<37 = 2 * 18 + 1 \\> 6>; here M<k> is 18 and M<b>
is 1, so the binary expansion of 37 is the same as that for 18, but
with an extra 1 on the end.  And in fact the expansion for 37 is
100101 and for the binary expansion for 18 is 10010.
This is a code backslash: C<\\\\>
", \&prelim);
