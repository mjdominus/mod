
package Mod::Code;
use Mod::Generic;
@ISA = 'Mod::Generic';

sub N { "" }

%paragraph = (
              'whitespace' => \&N,
              'prose' => \&N,
              'program' => \&program,
              'command' => \&N,
             );

%command = 
  (
   'stop' => \&Stop,

   'test' => \&test,
   'starttest' => \&test,
   'endtest' => \&test,
   'auxtest' => \&test,
   'testable' => \&test,
   'inline_testcode' => \&N,

   'startpicture' => \&pic,
   'picture' => \&pic,
   'endpicture' => \&pic,
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

sub extension () { 'code' };

sub init {
  my $self = shift;
  "";
}

sub fin { "" }

sub prose { "" }

sub whitespace { "" }

sub test {
  my ($self, $tag, $text, $progname, @args) = @_;
  if ($tag eq "test" || $tag eq "starttest" || $tag eq "auxtest") {
    if ($self->{in_test}) {
      $self->warning("nested test tags");
    } else {
      $self->{in_test} = 1;
    }
  } elsif ($tag eq "testable") {
    if ($self->{in_test}) {
      $self->warning("nested test tags");
    } else {
      $self->{in_test} = "x";
    }
  } elsif ($tag eq "endtest") {
    if ($self->{in_test}) {
      $self->{in_test} = 0;
    } else {
      $self->warning("close test tag without open");
    }
  } else {
     die "Missing handler for command '$tag'";
  }
  "";
}

sub pic {
  my ($self, $tag, $text, $progname, @args) = @_;
  if ($tag eq "picture" || $tag eq "startpicture") {
    if ($self->{in_pic}) {
      $self->warning("nested pic tags");
    } else {
      $self->{in_pic} = 1;
    }
  } elsif ($tag eq "endpicture") {
    if ($self->{in_pic}) {
      $self->{in_pic} = 0;
    } else {
      $self->warning("close pic tag without open");
    }
  } else {
     die "Missing handler for command '$tag'";
  }
  "";
}

sub program { 
  my ($self, $text, @args) = @_;
  if ($self->{in_test} && $self->{in_test} ne "x" || $self->{in_pic}) {
    return "";
  } else {
    return $text ."\n\n";
  }
}

sub Stop {
  return '', Stop => 1;
}


################################################################

1;

__DATA__
This work has been submitted to Morgan Kaufmann Publishers for
possible publication.  Copyright may be transferred without notice,
after which this version may no longer be accessible.

This file is copyright &copy; 2004 Mark-Jason Dominus.  Unauthorized
distribution in any medium is absolutely forbidden.




