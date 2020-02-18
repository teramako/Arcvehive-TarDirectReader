package Archive::TarDirectReader;
use strict;
no strict 'refs';
use Carp;
use Archive::TarDirectReader::Entry;

our $FOOTTER = chr(0x00) x 512;
sub new {
  my $class = shift;
  my $file = shift;
  my %opt = %{$_[0]};
  my $self = {
    gzipped => $opt{gzipped} || 0,
    _closed => 0,
    FH => undef
  };
  if (ref $file eq "GLOB") {
    $self->{FH} = $file;
  } else {
    $self->{FILE} = $file;
  }
  bless $self, $class;
  return $self;
}

sub _open {
  my $self = shift;
  if ($self->{FH}) {
    carp sprintf("Tar handle is already opened (fileno: `%s')", fileno($self->{FH}));
    return 0;
  }
  my $fh;
  if ($self->{gzipped}) {
    open($fh, "-|:raw", "gzip", "-dc", $self->{FILE}) or
      croak sprintf("open gzipped file (%s) was failed: %s", $self->{FILE}, $!);
  } else {
    open($fh, "<:raw", $self->{FILE}) or
      croak sprintf("open file (%s) was failed: %s", $self->{FILE}, $!);
  }
  $self->{FH} = $fh;
  return 1;
}
sub entries {
  my $self = shift;
  $self->_open() unless (defined $self->{FH});
  my $fh = $self->{FH};
  my $tarEntry;
  return sub {
    if (defined $tarEntry) {
      $tarEntry->close();
      $self->{CurrentEntry} = undef;
    }
    my $len = read($fh, my $buf, 512);
    if ($buf eq $FOOTTER) {
      return undef;
    }
    $tarEntry = new Archive::TarDirectReader::Entry($fh, $buf);
    $self->{CurrentEntry} = $tarEntry;
    return $tarEntry;
  };
}
sub current { shift->{CurrentEntry}; }
sub close {
  my $self = shift;
  $self->{CurrentEntry} = undef;
  return if ($self->{_closed});
  $self->{_closed} = 1;
  return CORE::close($self->{FH});
}

1;

