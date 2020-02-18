package Archive::TarDirectReader::ReadHandle;
use Carp;
use Tie::Handle;
our @ISA = qw(Tie::Handle);
our $WARN = 0;
sub new {
  my $class = shift;
  my $ch = \do{local *HANDLE;*HANDLE};
  tie(*$ch, $class, @_);
  return $ch;
}
sub TIEHANDLE {
  my ($class, $entry) = @_;
  my $self = {
    entry => $entry,
    FH => $entry->{__FH__},
    size => $entry->{size},
    pos => 0,
    buf => "",
    closed => 0
  };
  return bless($self, $class);
}
sub READ {
  my $self = shift;
  my $buf = \shift;
  my $len = shift;
  my $offset = shift || 0;
  if ($self->{pos} + $len > $self->{size}) {
    $len = $self->{size} - $self->{pos};
  }
  my $realLen = CORE::read($self->{FH}, $$buf, $len, $offset);
  $self->{pos} += $realLen;
  return $realLen;
}
sub READLINE {
  my $self = shift;
  my $buf = "";
  return undef if ($self->EOF);
  while ($self->{pos} < $self->{size}) {
    my $c = CORE::getc($self->{FH});
    ++$self->{pos};
    $buf .= $c;
    last if ($c eq $/);
  }
  return $buf;
}
sub GETC {
  my $self = shift;
  if ($self->{pos} < $self->{size}) {
    ++$self->{pos};
    return CORE::getc($self->{FH});
  }
  return undef;
}
sub TELL { shift->{pos} }
sub EOF {
  my $self = shift;
  return 1 if ($self->{pos} >= $self->{size});
  return 0;
}
sub CLOSE {
  my $self = shift;
  return "" if ($self->{closed});
  my $fh = $self->{FH};
  my $buf;
  my $end = $self->{entry}->blocks * 512;
  while ($self->{pos} < $end) {
    my $rest = $end - $self->{pos};
    $self->{pos} += CORE::read($fh, $buf, ($rest>512 ? 512 : $rest));
  }
  $self->{closed} = 1;
  return 1;
}
sub UNTIE   {
  my $self=shift;
  foreach my $key (keys $self) {
    delete $self->{$key};
  }
}
sub DESTROY {
  my $self=shift;
  foreach my $key (keys $self) {
    delete $self->{$key};
  }
}

1;

