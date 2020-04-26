C<exhausted?> here is as in the previous section.  The C<next>
operation doesn't return anything; it just tells the iterator to
forget the current value and to get ready to deliver the next value.
C<value> tells the iterator to return the current value; if we make
two calls to C<$it-\>('value')> without C<$it-\>('next')> in between,
we'll get the same value both times.
