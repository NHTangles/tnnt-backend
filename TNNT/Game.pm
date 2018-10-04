#!/usr/bin/env perl

#=============================================================================
# Object representing single game.
#=============================================================================

package TNNT::Game;

use integer;

use Moo;
use TNNT::Config;

with 'TNNT::ScoringList';



#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

has role      => ( is => 'ro', required => 1 );
has race      => ( is => 'ro', required => 1 );
has gender    => ( is => 'ro', required => 1 );
has align     => ( is => 'ro', required => 1 );
has gender0   => ( is => 'ro', required => 1 );
has align0    => ( is => 'ro', required => 1 );
has name      => ( is => 'ro', required => 1 );
has death     => ( is => 'ro', required => 1 );
has turns     => ( is => 'ro', required => 1 );
has realtime  => ( is => 'ro', required => 1 );
has starttime => ( is => 'ro', required => 1 );
has endtime   => ( is => 'ro', required => 1 );
has points    => ( is => 'ro', required => 1 );
has deathlev  => ( is => 'ro', required => 1 );
has maxlvl    => ( is => 'ro', required => 1 );
has hp        => ( is => 'ro', required => 1 );
has maxhp     => ( is => 'ro', required => 1 );
has deaths    => ( is => 'ro', required => 1 );
has elbereths => ( is => 'ro' );

# convert hexdecimal values

has conduct   => (
  is => 'ro',
  required => 1,
  coerce => sub { hex($_[0]) },
);

has achieve   => (
  is => 'ro',
  required => 1,
  coerce => sub { hex($_[0]) },
);

has tnntachieve0 => (
  is => 'ro',
  coerce => sub { no warnings 'portable'; hex($_[0]) },
);

has tnntachieve1 => (
  is => 'ro',
  coerce => sub { no warnings 'portable'; hex($_[0]) },
);

has tnntachieve2 => (
  is => 'ro',
  coerce => sub { no warnings 'portable'; hex($_[0]) },
);

# reference to TNNT::Player object

has player => (
  is => 'rw',
);

# list of achievements

has achievements => (
  is => 'ro',
  lazy => 1,
  builder => 1,
);

# index number

has n => (
  is => 'rw',
);

# source tag

has src => (
  is => 'ro',
  required => 1,
);

# clan unique flag

has clan_unique => (
  is => 'rw',
);



#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#=============================================================================
#=============================================================================

sub is_ascended
{
  my ($self) = @_;

  return ($self->death() =~ /^ascended/);
}



#=============================================================================
# Display game on console (for development purposes only)
#=============================================================================

sub disp
{
  my ($self) = @_;

  printf(
    "%4d  %-16s  %s-%s-%s-%s  %s  %6d turns  %8d points  %s\n",
    $self->n(),
    $self->name(),
    $self->role(), $self->race(), $self->gender0(), $self->align0(),
    scalar(gmtime($self->endtime())),
    $self->turns(), $self->points(), $self->death()
  );
}



#=============================================================================
# Return conducts as either their number (in scalar context) or list of
# conduct shortcodes (in list context)
#=============================================================================

sub conducts
{
  my $self = shift;
  my $cfg = TNNT::Config->instance()->config()->{'conducts'};
  my $conduct_bitfield = $self->conduct();
  my $achieve_bitfield = $self->achieve();
  my $elbereths = $self->elbereths();

  my @conducts;

  #--- get reverse code-to-value mapping for conducts and also ordering

  my %con_to_val = reverse %{$cfg->{'conduct'}};
  my %ach_to_val = reverse %{$cfg->{'achieve'}};
  my @order = @{$cfg->{'order'}};

  #---

  foreach my $c (@order) {

    if($c eq 'elbe' && defined $elbereths && !$elbereths) {
      push(@conducts, $c);
      last;
    }

    if(exists $con_to_val{$c} && $conduct_bitfield) {
      if($conduct_bitfield & $con_to_val{$c}) {
        push(@conducts, $c);
      }
    }

    elsif(exists $ach_to_val{$c} && $achieve_bitfield) {
      if($achieve_bitfield & $ach_to_val{$c}) {
        push(@conducts, $c);
      }
    }

  }

  #--- return value depending on context

  return wantarray ? @conducts : scalar(@conducts);
}



#-----------------------------------------------------------------------------
# Create list of achievements out of the xlogfile fields 'achieve' and TNNT
# specific 'tnntachieve0' and 'tnntachieve1'. The result is an array of
# achievement shortnames (as referenced in the configuration file)
#-----------------------------------------------------------------------------

sub _build_achievements
{
  no warnings 'portable';

  my ($self) = @_;
  my $cfg = TNNT::Config->instance()->config()->{'achievements'};

  my @achievements;

  for my $field (qw(achieve tnntachieve0 tnntachieve1 tnntachieve2)) {
    next if !$self->$field();
    my @found = grep {
      exists $cfg->{$_}{$field}
      && $cfg->{$_}{$field}
      && hex($cfg->{$_}{$field}) & $self->$field()
    } keys %$cfg;

    push(@achievements, @found) if @found;
  }

  return \@achievements;
}


#-----------------------------------------------------------------------------
# Returns true if supplied achievements were achieved by the game.
#-----------------------------------------------------------------------------

sub has_achievement
{
  my $self = shift;
  my @wanted = @_;
  my $achievements = $self->achievements();

  my $found = 1;

  for my $ach (@wanted) {
    if(!grep { $_ eq $ach } @$achievements) {
      $found = 0;
      last;
    }
  }

  return $found;
}


#-----------------------------------------------------------------------------
# Return character combination string.
#-----------------------------------------------------------------------------

sub combo
{
  my ($self) = @_;

  return join('-',
    $self->role(),
    $self->race(),
    $self->gender0(),
    $self->align0()
  );
}


#-----------------------------------------------------------------------------
# Format duration field into homan readable form
#-----------------------------------------------------------------------------

sub _format_duration
{
  my ($self) = @_;

  my $realtime = $self->realtime();
  my ($d, $h, $m, $s) = (0,0,0,0);
  my $duration;

  $d = $realtime / 86400;
  $realtime %= 86400;

  $h = $realtime / 3600;
  $realtime %= 3600;

  $m = $realtime / 60;
  $realtime %= 60;

  $s = $realtime;

  $duration = sprintf("%s:%02s:%02s", $h, $m, $s);
  if($d) {
    $duration = sprintf("%s, %s:%02s:%02s", $d, $h, $m, $s);
  }

  return $duration;
}


#----------------------------------------------------------------------------
# Format the endtime xlogfile fileds.
#----------------------------------------------------------------------------

sub _format_endtime
{
  my ($self) = @_;

  my @t = gmtime($self->endtime());
  return sprintf("%04d-%02d-%02d %02d:%02d", $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1]);
}


#----------------------------------------------------------------------------
# Format the starttime xlogfile fileds.
#----------------------------------------------------------------------------

sub _format_starttime
{
  my ($self) = @_;

  my @t = gmtime($self->starttime());
  return sprintf("%04d-%02d-%02d %02d:%02d", $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1]);
}


#-----------------------------------------------------------------------------
# Return export data.
#-----------------------------------------------------------------------------

sub export
{
  my ($self) = @_;

  my %d = (
    n            => $self->n(),
    role         => $self->role(),
    race         => $self->race(),
    gender       => $self->gender0(),
    align        => $self->align0(),
    name         => $self->name(),
    death        => $self->death(),
    turns        => $self->turns(),
    realtime     => $self->_format_duration(),
    starttime    => $self->_format_starttime(),
    endtime      => $self->_format_endtime(),
    points       => $self->points(),
    deathlev     => $self->deathlev(),
    maxlvl       => $self->maxlvl(),
    hp           => $self->hp(),
    maxhp        => $self->maxhp(),
    achievements => $self->achievements(),
    src          => $self->src()->name(),
    clan_unique  => $self->clan_unique(),
  );

  if($self->is_ascended()) {
    $d{'conducts'} = [ $self->conducts() ],
  }

  return \%d;
}



#=============================================================================

1;
