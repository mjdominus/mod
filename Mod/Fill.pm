
package Mod::Fill;
use Exporter;
@EXPORT = 'fill';
@ISA = 'Exporter';

sub fill {
  my ($self, $text, $width, $leader) = @_;
  $leader = '' unless defined $leader;
  $width ||= $self->{width};

  # Hold paragraph so far and current line
  my ($p, $l) = ('', $leader);

  my @words = split /\s+/, $text;

 WORD:
  for my $w (@words) {
    if (length($w) >= $width) {
      # special case for long words
      $p .= $l . "\n";
      $p .= $w . "\n";
      $l = '';
      next WORD;
    }
    if (length($w) + length($l) + 1 <= $width) {
      $l .= ' ' if $l ne '';
      $l .= $w;
    } else {
      $p .= $l . "\n";
      $l = $leader;
      redo WORD;
    }
  }

  $p .= $l . "\n" unless $l eq $leader;
  return $p;
}

1;
