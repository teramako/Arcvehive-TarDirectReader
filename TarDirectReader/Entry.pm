package Archive::TarDirectReader::Entry;
use Carp;
use Archive::TarDirectReader::ReadHandle;

use constant BLOCK_SIZE => 512;

my $TYPEFLAGS = {
  "0" => "FILE",
  "1" => "HARD LINK",
  "2" => "SYMBOLIC LINK",
  "3" => "CHARACTAR DEVICE",
  "4" => "BLOCK DEVICE",
  "5" => "DIRECTORY",
  "6" => "FIFO",
};
sub new {
  my ($class, $fh, $buf) = @_;
  my $self = {
    __FH__=> $fh,
    __CH__ => undef,
    _closed => 0
  };
  bless $self, $class;
  $self->_init($buf);
  return $self;
}
sub _init {
  my $self = shift;
  my $header = $self->parseHeader(shift);
  foreach my $key (keys $header) {
    $self->{$key} = $header->{$key};
  }
}
sub _unpack_header {
  my ($path, $mode, $uid, $gid, $size, $mtime, $chksum, $typeflag, $linkname, $magic, $version, $uname, $gname) =
    unpack("A100A8A8A8A12A12A8A1A100A6A2A32A32", shift);
  return {
    path => $path,
    mode => $mode,
    uid => oct($uid),
    gid => oct($gid),
    size => oct($size),
    mtime => oct($mtime),
    chksum => oct($chksum),
    type => $typeflag,
    linkname => $linkname,
    magic => $magic,
    version => $version,
    uname => $uname,
    gname => $gname
  };
}
sub parseHeader {
  my ($self, $buf) = @_;
  my $blockCount = 0;
  unless (defined $buf) {
    read($self->{__FH__}, $buf, BLOCK_SIZE);
  }
  my $header;
  my $opt = {};
  my $complete = 0;
  do {
    $header = _unpack_header($buf);
    ++$blockCount;
    my $t = $header->{type};
    if (defined $TYPEFLAGS->{$t}) {
      $complete = 1;
    } elsif ($t eq "L" or $t eq "K") { # GNU Long name or Long link
      my $size = $header->{size};
      read($self->{__FH__}, my $name, $size);
      $blockCount += int($size / BLOCK_SIZE);
      if ($t eq "L") {
        $opt->{path} = $name;
      } else {
        $opt->{linkname} = $name;
      }
      if ($size % BLOCK_SIZE > 0) {
        read($self->{__FH__}, $buf, $size % BLOCK_SIZE);
        ++$blockCount;
      }
      read($self->{__FH__}, $buf, BLOCK_SIZE);
    } else {
      carp sprintf("Unkown typeflag (%s): parsing tar header.", $t);
      return $header;
    }
  } while (!$complete);

  $self->{_headerBlocks} = $blockCount;
  foreach my $key (keys $opt) {
    $header->{$key} = $opt->{$key};
  }
  return $header;
}
sub path { shift->{path}; }
sub leafname {
  my @path = split('/', shift->{path});
  return $path[$#path];
}
sub size { shift->{size}; }
sub type {
  my $t = shift->{type};
  my $v = $TYPEFLAGS->{$t};
  return $v if (defined $v);
  croak "Unkown TarDirectReader typeflag: `$t'";
}
sub contentsHandle {
  my $self = shift;
  if ($self->{_closed}) {
    carp sprintf("TarDirectReader::Entry(%s) is already closed.", $self->{path});
    return;
  }
  if ($self->{size} <= 0) {
    carp sprintf("TarDirectReader::Entry(%s) has no contents.", $self->{path});
    return;
  }
  return $self->{__CH__} if (defined $self->{__CH__});
  $self->{__CH__} = new Archive::TarDirectReader::ReadHandle($self);
  return $self->{__CH__};
}
sub headerBlocks { shift->{_headerBlocks}; }
sub blocks {
  my $self = shift;
  my $size = $self->{size};
  $size += BLOCK_SIZE- ($size % BLOCK_SIZE) if ($size % BLOCK_SIZE > 0);
  return $size / BLOCK_SIZE;
}
sub close {
  my $self = shift;
  if (defined $self->{__CH__}) {
    CORE::close($self->{__CH__}) and $self->{_closed} = 1;
    return 1;
  }
  return "";
}

1;

