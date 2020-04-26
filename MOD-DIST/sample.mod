
=chapter About MOD

=section Introduction

This is very rough, because I haven't distributed it to anyone before.
It's not quite finished.  There are some changes I want to make to the
internals, and the TeX and LaTeX output drivers aren't done.
(The LaTeX one is barely begun.)

If I left anything out, let me know.

=section The Programs and How to Run Them

The conversion program is called C<mod>.  To use it:

        mod -o output-format [ -c chapter-number ] input-file

C<m2t> is the same as C<mod -o text>.
C<m2T> is the same as C<mod -o TeX>.
C<m2h> is the same as C<mod -o html>.
C<m2g> is the same as C<mod -o generic>.
C<m2c> is the same as C<mod -o crappy>.

C<crappy> is a trivial conversion to plain text.  If you want to
modify one of the drivers, you should probably have a look at
C<Mod::Crappy> first.  C<generic> is the base class from which the
others inherit.  It contains the MOD parsing code, escape sequence
translation, and so on.  One day I will write API documentation for
it.

If the input file is C<foo.mod>, the output file is C<foo.tex>, or
C<foo.html>, C<foo.txt>, or C<foo.crap>, as appropriate.

The C<-c> option is used for numbering sections.  (So that the
sections in chapter 4 get numbered 4.1, 4.2, etc.)  If you omit it,
MOD tries to guess the chapter number from the input filename.

=section Syntax

MOD is Pod-like.  Input is structured as paragraphs, separated by
blank lines.  

If every line in a paragraph is indented, it's program source code; if
not, it's prose.  
 
There is one exception to this rule: If the first character in a
source code line is a C<*>, the line is considered to be indented.  If
the paragraph is considered to be source code, because every line
begins with white space or C<*>, then the C<*>'s are removed.  The
driver gets an array of source code lines and an array indicating
which lines were starred.  Starred lines are 'special' and are
formatted specially.  You can assign whatever semantics you want to
'special'-ness, but in my book, 'special' lines are the ones that have
changed since the last time the reader saw the same code.  The HTML
driver sets the 'special' lines in bold purple font.  The text driver
sets 'special' lines with a C<*> in the left margin.  When the TeX
driver is finished, it will set the 'special' lines with a change bar
in the margin.  For example:

        # This is some program source code
        sub read_file {
*         local ($/, *FH);
          my $filename = shift;
*         open FH, "< $filename\n" or return;
          return <FH>;
        }

If a paragraph begins with an C<=> sign, it's a command.  MOD defines
a syntax and a recommended command set, but commands are implemented
by the various drivers, each in its own way.  Commands are
case-insensitive, but you should use all lowercase so that I can
reserve the capitalized names for nonstandard drivers.

=subsection Commands

At present, my standard drivers understand the following commands:

=bulletedlist

=item C<=startlisting> V<listingname>

=item C<=endlisting> V<listingname>

=item C<=listing> V<listingname>

=item C<=inline> V<listingname>

All program listings between these two marks are considered to be part
of the named program listing.  The text driver will dump the code to a
file named C<Programs/listingname> and inline it.  The HTML driver
will inline the code, with a link to C<Programs/listingname>.

Prose paragraphs between C<=startlisting> and C<=endlisting> are
typeset normally, but are not included in the listing.  So you can do:

=indented

The following function takes an argument and returns the next largest
prime number:

        =startlisting next_prime

                sub next_prime {
                  my $n = shift;
                  $n++;

        We need to increment C<$n> immediately, because the function
        is guaranteed to return a prime I<larger> than C<$n>.

                  while (1) {
                    return $n if is_prime($n);

        We saw F<is_prime> on page R<is_prime|page>.

                    $n++;    
                  }
                }
        =endlisting next_prime

The code, and only the code, will be inserted into
C<Programs/next_prime>.  

=endindented

Note that C<=startlisting> and C<=endlisting> commands need not nest
correctly.  It is permissible to have listings overlap.  If you have
two listings with the same name, the later one will be appended to the
earlier.

C<=listing> is synonymous with C<=startlisting>.

C<=inline> V<listingname> inserts the code for a previously defined
listing:

        Recall the function F<next_prime>, which we saw back in
        Chapter R<next_prime|chapter>:

        =inline next_prime

        This could be made more flexible by...

C<=startlisting>...C<=endlisting> may also make an entry in the index,
and may also define a crossreference for the C<R\<...\>> sequence.

=item C<=chapter> V<chaptertitle>

=item C<=section> V<sectiontitle>

=item C<=subsection> V<subsectiontitle>

=item C<=subsubsection> V<subsubsectiontitle>

Start a new chapter, section, etc.  Typesets the title appropriately
and adjusts the sections numbers.  The text file driver makes an
appropriate entry in the C<.mtc> (MOD Table of Contents) file.
(Someday this will be done by a special-purpose C<Mod::TOC> driver
instead.)  Drivers may also set up crossreference information for use
with C<R\<...\>>, described below.

=item C<=startpicture> V<picture>

=item C<=endpicture> V<picture>

The contents are ascii-art.  The text driver inserts this art
verbatim.  The HTML driver looks for an image file named
C<picturename> and inlines that instead.  The TeX driver will probably
look for C<picturename.ps> or something of the sort.

=item C<=note> V<text>

Ignored.   This is a comment.

=item C<=comment>

=item C<=endcomment>

Intervening text is discarded.  This may go away in the next
version because C<=note> was good enough.

=item C<=bulletedlist>

=item C<=endbulletedlist>

=item C<=numberedlist>

=item C<=endnumberedlist>

=item C<=item>

Start or close a list of the specified type.  C<=item> typesets a list
item.  Lists must be nested correctly; failure to do so will yield a
warning.  It's my intention for the 'start' to be optional on all
C<=startXXX> commands, but I haven't done it yet.

=item C<=indented>

=item C<=endindented>

Prose text that is indented, as for example a block quotation.

The existing drivers accept C<=maxim> and C<=endmaxim> as synonyms for
C<=indented>.  This will probably go away.

=item C<=stop>

End of the file; everything following is ignored.

=endbulletedlist


=subsection Escape Sequences

In a prose paragraph, and in certain command texts, certain escape
sequences are recognized.  They are all podlike: C<X\<text...\>> where
C<X> is some single letter.  For example:

=bulletedlist

=item  C<B\<...\>>

Typeset text in boldface.  (The text driver uses C<*asterisks*>)

=item  C<I\<...\>>  

Typeset text in italics.  (The text driver uses C<_underscores_>)

=item  C<C\<...\>>  

Typeset text as code.  (The text driver uses C<'quotes'>)

=endbulletedlist

Some replacements are carried out recursively.  For example, C<B\<foo
I\<bar\> baz\>> generates C<*foo _bar_ baz*>.  But no recursion is
done inside of C<C\<...\>>, so C<C\<B\<...\>\>> is rendered as
C<'B\<...\>'>.  I don't have a spec for this yet, but I do think it is
likely to do what you expect.

To put a literal C<\<> or C<\>> mark inside an escape sequence, backslash it.
To put a literal C<\\>  inside  an escape sequence, backslash it.  For example:

        To call a method, use C<$object-\>method(arguments...)>

The backslashes are mandatory.  This sucks, but not as much as Perl's
crapulent C<C\<E\<gt\>\>> syntax.

The rest of the escape sequences are:

=bulletedlist

=item C<F\<...\>>

This is a function name.  It is probably typeset like code.  Some
drivers may choose to append notation like C<()> to the function name.
Some drivers may automatically make a special index entry for the
function.  This may get moved out of the standard drivers into my own
private drivers.

=item C<N\<...\>>

Typeset a footnote.  The text driver just inserts C<[[Footnote:
...]]>.  The HTML driver generates a hotlinked footnote that appears
at the bottom of the page.  The TeX driver will use C<\\footnote{...}>.

=item C<V\<...\>>

Typeset a mathematical variable name.  This usually means italics or
the equivalent.  For example:

              The argument to F<next_prime> is the smallest prime number 
              V<p> which is larger than the specified argument, V<n>.

=item C<M\<...\>>

An extended math formula.  The contents should be in TeX format.  The
TeX driver will insert this verbatim.  The text driver maintains a
database showing an approximate plain text representation of the
formula.  Formulas that are listed in the database have their
equivalent translations inserted into the output.  Formulas that are
not listed in the database are appended to the C<badmath> file, a
warning is printed, and the TeX version of the formula is inserted
directly.

After the run is over, you can run the program C<defmath>, which reads
the C<badmath> file and prompts you for additions to the database.

The HTML driver presently does the same thing that the text driver
does, but this might change.  It might have a database if inlinable
gifs, or use TeX to generate the gifs if one is missing.

=item C<R\<reference\>>

Someday this will generate a crossreference, but it isn't fully
implemented yet.  The intent is that you'll be able to write

                R<carrots|section>

and the driver will insert the section number of the section titled
I<Carrots>; similarly C<C\<Iterators|chapter\>> or
C<C\<next_prime|page\>> or whatever.  At present, there is no way to
define a cross-reference.  The existing drivers inline text of the
form C<section ???> or C<page ???>.  This behavior is wrong; they
should just inline C<???>. 

=item C<T\<...\>>

Generate a reprensentation of an HTML tag.  The text driver turns
C<T\<font\>> into C<\<font\>>.  The HTML driver turns it into
C<\<tt\>&lt;font&gt;\</tt\>>.  This is for convenience so that you
don't have to type C<C\<\\<tag\\\>\>> everywhere. 

=item C<X\<...\>>

Generate an index entry.  An index entry has four properties: The text
that is actually typeset inline, the text that is typeset in the
index, the alphabetizing key for the index entry, and the style that
is used for the page number in the index.  Support isn't complete yet.

=bulletedlist

=item C<X\<fish\>>

typesets 'fish' inline and inserts it into the index.  For example:

                It is not known whether X<fish> obey the X<Poisson
                distribution>.  

=item C<X\<fish|i\>>

is the same, but nothing is typeset inline.  (The C<i> is for
'invisible.)  For example:

                Some might say that our scaly friends of the deep are
                ignorant of statistics.X<fish|i> It is not known
                whether they obey the X<Poisson distribution>.
                X<Distribution, Poisson|i>

The output from this will be:

                Some might say that our scaly friends of the deep are
                ignorant of statistics. It is not known whether they
                obey the Poisson distribution.

Plus index entries for 'fish', 'Poisson distribution', and
'Distribution, Poisson'.

=item C<X\<fish|d\>>

indicates that this is the index entry for the I<definition> of
'fish'.  'fish' is typeset inline in italics, and there may be a
special annotation in the index (an italicized page number, for
example) to indicate that this reference is special.  For example:

                These water-dwelling vertebrates are known as X<fish|d>.

=item C<X\<fish|(\>>

=item C<X\<fish|)\>>

Material pertaining to 'fish' starts/ends here.  C<(> and C<)> imply
C<i>.  The index entry will come out with a range of page numbers, as
C<fish, 273--284>.

=item C<X\<fish|K\<foo\>\>>

Like C<X\<fish\>>, but alphabetize under 'foo'.  C<K\<...\>> has no
special meaning elsewhere.

=item C<X\<fish|B\>>

Like C<X\<fish\>>, but the page number in the index should be in bold
face.

=item C<X\<fish|I\>>

Like C<X\<fish\>>, but the page number in the index should be in
italics.

=item C<X\<fish|T\<see also I\<ichthyes\>\>\>>

Inserts the note "see also _ichthyes_" in the index under 'fish'.

=endbulletedlist
          
The intent is that flags can be combined, so that you might write
C<X\<fish|K\<ichthyes\>id\>> to indicate that the current page is the
point at which 'fish' is defined, but the word 'fish' is not actually
inserted at that point on the page, and the entry for 'fish' should be
alphabetized under 'ichthyes'.

In general, if there is a C<|> in the sequence, everything after the last
C<|> is taken to be a flag option.  Any other C<|>s separate subentries.
For example,

                X<fruits|apples|i>

inserts a subentry in the index under 'fruits':

=indented

                fruits
                  apples, 357

=endindented

If you want to omit the C<i> here, the word 'fruits' will be inserted
inline.  You have to say C<X\<fruits|apples|\>>.  
C<X\<fruits|apples\>> won't work because MOD  will try to interpret the
C<apples> as a set of flags.

All of the drivers generate the inline text correctly, but none
actually builds an index.  I'm planning to write another driver,
C<Mod::Index>, which extracts the index terms and builds an index data
file, which the other drivers can then read and transform into a
formatted index.

=endbulletedlist

=section Summary

I think that's all, except for the API documentation.  Drop me a note
if anything is missing.

=stop


