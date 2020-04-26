

=numberedlist

=item If M<n> is 1, its binary expansion is 1, and we may ignore the
      rest of the procedure.  Otherwise:

=item Compute M<k> and M<b> so that M<n = 2k + b> and M<b = 0 {\rm or} 1>.
      To do this, simply divide M<n> by 2; M<k> is the quotient, and M<b>
      is the remainder, 0 if M<n> was even, and 1 if M<n> was odd.

=item Compute the binary expansion for M<k>m using I<this> method.
      Call the result M<E>. 

=item The binary expansion for M<n> is M<Eb>.

=endnumberedlist

