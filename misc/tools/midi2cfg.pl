#!/usr/bin/perl

# converter from Type 1 MIDI files to CFG files that control bots with the Tuba and other weapons for percussion (requires g_weaponarena all)
# usage:
#   perl midi2cfg.pl filename.mid basenote walktime "x y z" "x y z" "x y z" ... "/" "x y z" "x y z" ... > filename.cfg

use strict;
use warnings;
use MIDI;
use MIDI::Opus;

use constant MIDI_FIRST_NONCHANNEL => 17;
use constant MIDI_DRUMS_CHANNEL => 10;

my ($filename, $transpose, $walktime, $staccato, @coords) = @ARGV;
my @coords_percussion = ();
my @coords_tuba = ();
my $l = \@coords_tuba;
for(@coords)
{
	if($_ eq '/')
	{
		$l = \@coords_percussion;
	}
	else
	{
		push @$l, [split /\s+/, $_];
	}
}

my $opus = MIDI::Opus->new({from_file => $filename});
#$opus->write_to_file("/tmp/y.mid");
my $ticksperquarter = $opus->ticks();
my $tracks = $opus->tracks_r();
my @tempi = (); # list of start tick, time per tick pairs (calculated as seconds per quarter / ticks per quarter)
my $tick;

$tick = 0;
for($tracks->[0]->events())
{   
    $tick += $_->[1];
    if($_->[0] eq 'set_tempo')
    {   
        push @tempi, [$tick, $_->[2] * 0.000001 / $ticksperquarter];
    }
}
sub tick2sec($)
{
    my ($tick) = @_;
    my $sec = 0;
    my $curtempo = [0, 0.5 / $ticksperquarter];
    for(@tempi)
    {
        if($_->[0] < $tick)
        {
			# this event is in the past
			# we add the full time since the last one then
			$sec += ($_->[0] - $curtempo->[0]) * $curtempo->[1];
        }   
        else
        {
			# if this event is in the future, we break
			last;
        }
		$curtempo = $_;
    }
	$sec += ($tick - $curtempo->[0]) * $curtempo->[1];
	return $sec;
}

# merge all to a single track
my @allmidievents = ();
my $sequence = 0;
for my $track(0..@$tracks-1)
{
	$tick = 0;
	for($tracks->[$track]->events())
	{
		my ($command, $delta, @data) = @$_;
		$tick += $delta;
		push @allmidievents, [$command, $tick, $sequence++, $track, @data];
	}
}
@allmidievents = sort { $a->[1] <=> $b->[1] or $a->[2] <=> $b->[2] } @allmidievents;





my @busybots_percussion = map { undef } @coords_percussion;
my @busybots_tuba       = map { undef } @coords_tuba;

my $notes = 0;
sub busybot_findfree($$$)
{
	my ($time, $vchannel, $note) = @_;
	my $l = ($vchannel < MIDI_FIRST_NONCHANNEL) ? \@busybots_tuba : \@busybots_percussion;
	my $c = ($vchannel < MIDI_FIRST_NONCHANNEL) ? \@coords_tuba : \@coords_percussion;
	for(0..@$l-1)
	{
		if(!$l->[$_])
		{
			my $bot = {id => $_ + 1, busy => 0, busytime => 0, channel => $vchannel, curtime => -$walktime, curbuttons => 0, noteoffset => 0};
			$l->[$_] = $bot;

			# let the bot walk to his place
			printf "m $_ $c->[$_]->[0] $c->[$_]->[1] $c->[$_]->[2]\n";

			return $bot;
		}
		return $l->[$_] if
			(($vchannel < MIDI_FIRST_NONCHANNEL) || ($l->[$_]{channel} == $vchannel))
			&&
			!$l->[$_]{busy}
			&&
			$time > $l->[$_]{busytime};
	}
	use Data::Dumper;
	print STDERR Dumper $l;
	die "No free channel found at time $time ($notes notes active)\n";
}

sub busybot_find($$)
{
	my ($vchannel, $note) = @_;
	my $l = ($vchannel < MIDI_FIRST_NONCHANNEL) ? \@busybots_tuba : \@busybots_percussion;
	for(0..@$l-1)
	{
		return $l->[$_] if
			$l->[$_]
			&&
			$l->[$_]{busy}
			&&
			$l->[$_]{channel} == $vchannel
			&&
			defined $l->[$_]{note}
			&&
			$l->[$_]{note} == $note;
	}
	return undef;
}

sub busybot_advance($$)
{
	my ($bot, $t) = @_;
	my $t0 = $bot->{curtime};
	if($t != $t0)
	{
		#print "sv_cmd bot_cmd $bot->{id} wait @{[$t - $t0]}\n";
		print "w $bot->{id} $t\n";
	}
	$bot->{curtime} = $t;
}

sub busybot_setbuttonsandadvance($$$)
{
	my ($bot, $t, $b) = @_;
	my $b0 = $bot->{curbuttons};
	my $press = $b & ~$b0;
	my $release = $b0 & ~$b;
	busybot_advance $bot => $t - 0.10
		if $release & (32 | 64);
	print "r $bot->{id} attack1\n" if $release & 32;
	print "r $bot->{id} attack2\n" if $release & 64;
	busybot_advance $bot => $t - 0.05
		if ($release | $press) & (1 | 2 | 4 | 8 | 16 | 128);
	print "r $bot->{id} forward\n" if $release & 1;
	print "r $bot->{id} backward\n" if $release & 2;
	print "r $bot->{id} left\n" if $release & 4;
	print "r $bot->{id} right\n" if $release & 8;
	print "r $bot->{id} crouch\n" if $release & 16;
	print "r $bot->{id} jump\n" if $release & 128;
	print "p $bot->{id} forward\n" if $press & 1;
	print "p $bot->{id} backward\n" if $press & 2;
	print "p $bot->{id} left\n" if $press & 4;
	print "p $bot->{id} right\n" if $press & 8;
	print "p $bot->{id} crouch\n" if $press & 16;
	print "p $bot->{id} jump\n" if $press & 128;
	busybot_advance $bot => $t
		if $press & (32 | 64);
	print "p $bot->{id} attack1\n" if $press & 32;
	print "p $bot->{id} attack2\n" if $press & 64;
	$bot->{curbuttons} = $b;
}

my %notes = (
	-18 => '1lbc',
	-17 => '1bc',
	-16 => '1brc',
	-13 => '1frc',
	-12 => '1c',
	-11 => '2lbc',
	-10 => '1rc',
	-9 => '1flc',
	-8 => '1fc',
	-7 => '1lc',
	-6 => '1lb',
	-5 => '1b',
	-4 => '1br',
	-3 => '2rc',
	-2 => '2flc',
	-1 => '1fl',
	0 => '1',
	1 => '2lb',
	2 => '1r',
	3 => '1fl',
	4 => '1f',
	5 => '1l',
	6 => '2fr',
	7 => '2',
	8 => '1brj',
	9 => '2r',
	10 => '2fl',
	11 => '2f',
	12 => '2l',
	13 => '2lbj',
	14 => '1rj',
	15 => '1flj',
	16 => '1fj',
	17 => '1lj',
	18 => '2frj',
	19 => '2j',
	21 => '2rj',
	22 => '2flj',
	23 => '2fj',
	24 => '2lj'
);

my $note_min = +99;
my $note_max = -99;
sub getnote($$)
{
	my ($bot, $note) = @_;
	$note_max = $note if $note_max < $note;
	$note_min = $note if $note_min > $note;
	$note -= $transpose;
	$note -= $bot->{noteoffset};
	my $s = $notes{$note};
	return $s;
}

sub busybot_playnoteandadvance($$$)
{
	my ($bot, $t, $note) = @_;
	my $s = getnote $bot => $note;
	return (warn("note $note not found"), 0)
		unless defined $s;
	my $buttons = 0;
	$buttons |= 1 if $s =~ /f/;
	$buttons |= 2 if $s =~ /b/;
	$buttons |= 4 if $s =~ /l/;
	$buttons |= 8 if $s =~ /r/;
	$buttons |= 16 if $s =~ /c/;
	$buttons |= 32 if $s =~ /1/;
	$buttons |= 64 if $s =~ /2/;
	$buttons |= 128 if $s =~ /j/;
	busybot_setbuttonsandadvance $bot => $t, $buttons;
	return 1;
}

sub busybot_stopnoteandadvance($$$)
{
	my ($bot, $t, $note) = @_;
	my $s = getnote $bot => $note;
	return 0
		unless defined $s;
	my $buttons = $bot->{curbuttons};
	#$buttons &= ~(32 | 64);
	$buttons = 0;
	busybot_setbuttonsandadvance $bot => $t, $buttons;
	return 1;
}

sub note_on($$$)
{
	my ($t, $channel, $note) = @_;
	++$notes;
	if($channel == MIDI_DRUMS_CHANNEL)
	{
		$channel = MIDI_FIRST_NONCHANNEL + $note; # percussion
		return if !@coords_percussion;
	}
	my $bot = busybot_findfree($t, $channel, $note);
	if($channel < MIDI_FIRST_NONCHANNEL)
	{
		if(busybot_playnoteandadvance $bot => $t, $note)
		{
			$bot->{busy} = 1;
			$bot->{note} = $note;
			$bot->{busytime} = $t + 0.25;
			if($staccato)
			{
				busybot_stopnoteandadvance $bot => $t + 0.15, $note;
				$bot->{busy} = 0;
			}
		}
	}
	if($channel >= MIDI_FIRST_NONCHANNEL)
	{
		busybot_advance $bot => $t;
		print "p $bot->{id} attack1\n";
		print "r $bot->{id} attack1\n";
		$bot->{busy} = 1;
		$bot->{note} = $note;
		$bot->{busytime} = $t + 1.5;
	}
}

sub note_off($$$)
{
	my ($t, $channel, $note) = @_;
	--$notes;
	if($channel == MIDI_DRUMS_CHANNEL)
	{
		$channel = MIDI_FIRST_NONCHANNEL + $note; # percussion
	}
	my $bot = busybot_find($channel, $note)
		or return;
	$bot->{busy} = 0;
	if($channel < MIDI_FIRST_NONCHANNEL)
	{
		busybot_stopnoteandadvance $bot => $t, $note;
		$bot->{busytime} = $t + 0.25;
	}
}

print 'alias p "sv_cmd bot_cmd $1 presskey $2"' . "\n";
print 'alias r "sv_cmd bot_cmd $1 releasekey $2"' . "\n";
print 'alias w "sv_cmd bot_cmd $1 wait_until $2"' . "\n";
print 'alias m "sv_cmd bot_cmd $1 moveto \"$2 $3 $4\""' . "\n";

my %midinotes = ();
for(@allmidievents)
{
	my $t = tick2sec $_->[1];
	my $track = $_->[3];
	if($_->[0] eq 'note_on')
	{
		my $chan = $_->[4] + 1;
		if($midinotes{$chan}{$_->[5]})
		{
			note_off($t, $chan, $_->[5]);
		}
		note_on($t, $chan, $_->[5]);
		$midinotes{$chan}{$_->[5]} = 1;
	}
	elsif($_->[0] eq 'note_off')
	{
		my $chan = $_->[4] + 1;
		if($midinotes{$chan}{$_->[5]})
		{
			note_off($t, $chan, $_->[5]);
		}
		$midinotes{$chan}{$_->[5]} = 0;
	}
}

print STDERR "Range of notes: $note_min .. $note_max\n";
print STDERR "Safe transpose range: @{[$note_max - 19]} .. @{[$note_min + 13]}\n";
print STDERR "Unsafe transpose range: @{[$note_max - 24]} .. @{[$note_min + 18]}\n";
printf STDERR "%d bots allocated for tuba, %d for percussion\n", int scalar grep { defined $_ } @busybots_tuba, int scalar grep { defined $_ } @busybots_percussion;

my $n = 0;
for(@busybots_percussion, @busybots_tuba)
{
	++$n if $_ && $_->{busy};
}
if($n)
{
	die "$n channels blocked ($notes MIDI notes)";
}
