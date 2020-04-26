
package Mod::Template;
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
   'contlisting' => \&contlisting,

   'test' => \&test,
   'starttest' => \&test,
   'endtest' => \&test,
   'auxtest' => \&test,
   'testable' => \&test,
   'inline_testcode' => sub { "" },

   'startpicture' => \&caption,
   'endpicture' => \&caption,
   'picture' => \&caption,

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

################################################################

sub extension () { 'html' };    # XXX

sub init {
}

sub fin {
}

sub prose {
}

sub whitespace {
}

sub program {
}


sub Stop {
  return '', Stop => 1;
}

################################################################

# NOT FINISHED
sub T_index {
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




