Here the first call to F<try> stores 3 into C<$x>, and this is the
C<$x> to which C<print_x> refers.  But the second call to F<try>
creates a new <$x> variable and stores 7 into it, leaving 3 in the
original pad.  C<print_x> is never recompiled, and C<print_x>'s C<$x>
still refers to the original pad, so it ignores the new C<$x> entirely
and print 3.  C<try(15)> also prints C<3>, again because a new
variable is created in F<try>'s pad but not in C<print_x>'s pad.
