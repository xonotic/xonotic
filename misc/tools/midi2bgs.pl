#!/usr/bin/perl

# converter from Type 1 MIDI files to BGS files that control particle effects on maps
# usage:
#   perl midi2bgs.pl filename.mid tracknumber channelnumber offset notepattern > filename.bgs
# track and channel numbers -1 include all events
# in patterns, %1$s inserts the note name, %2$d inserts the track number, and %3$d inserts the channel number
# example:
#   perl midi2bgs.pl filename.mid -1 10 0.3 'note_%1$s_%3$d_%2$d' > filename.bgs

use strict;
use warnings;
use MIDI;
use MIDI::Opus;

my ($filename, $trackno, $channelno, $offset, $notepattern) = @ARGV;
$notepattern = '%1$s'
	unless defined $notepattern;
defined $offset
	or die "usage: $0 filename.mid {trackno|-1} {channelno|-1} offset [notepattern]\n";

my $opus = MIDI::Opus->new({from_file => $filename});
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
	return $sec + $offset;
}

my @notes = ('c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b');
my @notenames = ();
for my $octave (0..11)
{
	for(@notes)
	{
		if($octave <= 3)
		{
			push @notenames, uc($_) . ',' x (3 - $octave);
		}
		else
		{
			push @notenames, lc($_) . "'" x ($octave - 4);
		}
	}
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

my @outevents = (); # format: name, time in seconds, velocity
$tick = 0;

my %notecounters;
my %notecounters_converted;
for(@allmidievents)
{
	my $t = tick2sec $_->[1];
	my $track = $_->[3];
	next
		unless $trackno < 0 || $trackno == $track;
	if($_->[0] eq 'note_on')
	{
		my $chan = $_->[4] + 1;
		my $note = sprintf $notepattern, $notenames[$_->[5]], $trackno, $channelno;
		my $velocity = $_->[6] / 127.0;
		push @outevents, [$note, $t, $velocity]
			if($channelno < 0 || $channelno == $chan);
		++$notecounters_converted{$note}
			unless $notecounters{$chan}{$_->[5]};
		$notecounters{$chan}{$_->[5]} = 1;
	}
	elsif($_->[0] eq 'note_off')
	{
		my $chan = $_->[4] + 1;
		my $note = sprintf $notepattern, $notenames[$_->[5]], $trackno, $channelno;
		my $velocity = $_->[6] / 127.0;
		--$notecounters_converted{$note}
			if $notecounters{$chan}{$_->[5]};
		$notecounters{$chan}{$_->[5]} = 0;
		if($notecounters_converted{$note} == 0)
		{
			push @outevents, [$note, $t, 0]
				if($channelno < 0 || $channelno == $chan);
		}
	}
}
for(sort { $a->[0] cmp $b->[0] or $a->[1] <=> $b->[1] } @outevents)
{
    printf "%s %13.6f %13.6f\n", @$_;
}
