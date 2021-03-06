# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package CAF::Lock;

use strict;
use CAF::Object;
use CAF::Reporter;

use LC::Exception qw (SUCCESS throw_error);
use FileHandle;
use Fcntl qw(:flock);
#use Proc::ProcessTable;

use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(CAF::Reporter CAF::Object Exporter);

@EXPORT_OK = qw(FORCE_ALWAYS FORCE_IF_STALE);


use constant FORCE_NONE => 0;
use constant FORCE_ALWAYS => 1;
use constant FORCE_IF_STALE => 2;


=pod

=head1 NAME

CAF::Lock - Class for handling application instance locking

=head1 SYNOPSIS


  use CAF::Lock;

  $lock=CAF::Lock->new('/var/lock/quattor/spma');

  if ($lock->is_locked()) {...} else {...};

  unless ($lock->set_lock()) {...}
  unless ($lock->set_lock(10,2) {...}
  unless ($lock->set_lock(3,3,FORCE_IF_STALE)) {...}

  unless ($lock->unlock()) {....}


=head1 INHERITANCE

  CAF::Reporter

=head1 DESCRIPTION

The B<CAF::Lock> class provides methods for handling application locking.


=over

=cut

#------------------------------------------------------------
#                      Public Methods/Functions
#------------------------------------------------------------

=pod

=back

=head2 Public methods

=over 4

=item is_locked()

If a lock is set for the lock file, returns SUCCESS, undef otherwise.

=cut

sub is_locked() {
  my $self=shift;
  if (-e $self->{'LOCK_FILE'}) {
    my $fh=FileHandle->new("> ". $self->{'LOCK_FILE'});
    return SUCCESS unless (flock($fh, LOCK_EX|LOCK_NB));
  }
  return undef;
}

=pod

=item set_lock ($retries,$timeout,$force);

Tries $retries times to set the lock. If $force is set to FORCE_NONE
or not defined and the lock is set, it sleeps for
rand($timeout). Writes the current PID ($$) into the lock
file. Returns SUCCESS or undef on failure.

If $retries or $timeout are not defined or set to 0, only a single
attempt is done to acquire the lock.

If $force is set to FORCE_ALWAYS then the lockfile is just set
again, independently if the lock is already set by another application
instance.

If $force is set to FORCE_ALWAYS then neither $timeout nor $retries are taken
into account.

=cut

sub set_lock {
  my ($self,$retries,$timeout,$force)=@_;

  $retries=0 unless (defined $retries);
  $timeout=0 unless (defined $retries);

  if ($self->{LOCK_SET}) {
    # oops.
    $self->error("lock already set by this application instance");
    return undef;
  }

  my $tries=0;
  my $lock;
  while(1) {
    $tries++;
    $lock = $self->try_lock();
    if ($force == FORCE_ALWAYS) {
      $self->{LOCK_SET} = 1;
      $self->verbose("locking failed, but you used the force so here you go");
      return SUCCESS;
    }
    return SUCCESS if ($lock);

    if ($tries >= $retries) {
      $self->error("cannot acquire lock file: ".$self->{'LOCK_FILE'});
      return undef;
    }

    $self->verbose("lockfile is already held, try $tries out of $retries");
    my $sleep=rand($timeout);
    sleep($sleep);
  }
}

=pod

=item try_lock

Create the lockfile and return SUCCESS if we was able to flock() the file.

=cut

sub try_lock {
  my ($self) = @_;
  my $lf=FileHandle->new("> " . $self->{'LOCK_FILE'});
  if ( !$lf ) {
    $self->error("cannot create lock file: ".$self->{'LOCK_FILE'});
    return undef;
  }
  my $flockstatus = flock ($lf, LOCK_EX|LOCK_NB);
  if ( !$flockstatus ) {
    $self->error("cannot flock lock file: ".$self->{'LOCK_FILE'});
    return undef;
  }
  $self->{LOCK_FH}=$lf;
  $self->{LOCK_SET}=1;
  return SUCCESS;
}

=pod

=item unlock

Releases the lock and returns SUCCESS. Reports an error and returns
undef if the lock file cannot be released. If the object (application
instance) does not hold the lockfile, an error is reported and undef
is returned.

=cut

sub unlock {
  my $self=shift;
  if ($self->{LOCK_SET}) {
    # if we forced the lock LOCK_FH can be undef
    return SUCCESS unless ($self->{LOCK_FH});
    unless ($self->{LOCK_FH}->close) {
      $self->error("cannot close lock file: ",$self->{'LOCK_FILE'});
    }
    $self->{LOCK_SET}=undef;
  } else {
    $self->error("lock not held by this application instance, not unlocking");
    return undef;
  }
  return SUCCESS;
}


=pod

=item is_set

Returns SUCCESS if lock is set by application instance, undef otherwise

=cut

sub is_set {
  my $self=shift;
  return SUCCESS if ($self->{LOCK_SET});
  return undef;
}



=pod

=back

=head2 Private methods

=over 4

=item _initialize($lockfilename)

initialize the object. Called by new($lockfilename).

=cut

sub _initialize ($$$) {
  my ($self,$lockfilename) = @_;

  $self->{'LOCK_SET'}=undef;
  $self->{'LOCK_FILE'} = $lockfilename;
  return SUCCESS;

}


=pod

=back

=cut

1; ## END ##
