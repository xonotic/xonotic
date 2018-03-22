#!/usr/bin/perl

use strict;
use warnings;
use MIDI::Event;
use MIDI::Opus;
use MIDI::Track;

my ($filename, @others) = @ARGV;
my $opus = MIDI::Opus->new({from_file => $filename});

my %chanpos = (
	note_off => 2,
	note_on => 2,
	key_after_touch => 2,
	control_change => 2,
	patch_change => 2,
	channel_after_touch => 2,
	pitch_wheel_change => 2
);

my %isclean = (
	set_tempo => sub { 1; },
	note_off => sub { 1; },
	note_on => sub { 1; },
	control_change => sub { $_[3] == 64; },
);

sub abstime(@)
{
	my $t = 0;
	return map { [$_->[0], $t += $_->[1], @{$_}[2..(@$_-1)]]; } @_;
}

sub reltime(@)
{
	my $t = 0;
	return map { my $tsave = $t; $t = $_->[1]; [$_->[0], $t - $tsave, @{$_}[2..(@$_-1)]]; } @_;
}

sub clean(@)
{
	return reltime grep { ($isclean{$_->[0]} // sub { 0; })->(@$_) } abstime @_;
}

for(@others)
{
	my $opus2 = MIDI::Opus->new({from_file => $_});
	if($opus2->ticks() != $opus->ticks())
	{
		my $tickfactor = $opus->ticks() / $opus2->ticks();
		for($opus2->tracks())
		{
			$_->events(reltime map { $_->[1] = int($_->[1] * $tickfactor + 0.5); $_; } abstime $_->events());
		}
	}
	$opus->tracks($opus->tracks(), $opus2->tracks());
}

while(<STDIN>)
{
	chomp;
	my @arg = grep { $_ ne '' } split /\s+/, $_;
	my $cmd = shift @arg;
	print "Executing: $cmd @arg\n";
	if($cmd eq '#')
	{
		# Just a comment.
	}
	elsif($cmd eq 'clean')
	{
		my $tracks = $opus->tracks_r();
		$tracks->[$_]->events_r([clean($tracks->[$_]->events())])
			for 0..@$tracks-1;
	}
	elsif($cmd eq 'dump')
	{
		print $opus->dump({ dump_tracks => 1 });
	}
	elsif($cmd eq 'ticks')
	{
		if(@arg)
		{
			$opus->ticks($arg[0]);
		}
		else
		{
			print "Ticks: ", $opus->ticks(), "\n";
		}
	}
	elsif($cmd eq 'tricks')
	{
		print "haha, very funny\n";
	}
	elsif($cmd eq 'retrack')
	{
		my $tracks = $opus->tracks_r();
		my @newtracks = ();
		for(0..@$tracks-1)
		{
			for(abstime $tracks->[$_]->events())
			{
				my $p = $chanpos{$_->[0]};
				if(defined $p)
				{
					my $c = $_->[$p] + 1;
					push @{$newtracks[$c]}, $_;
				}
				else
				{
					push @{$newtracks[0]}, $_;
				}
			}
		}
		$opus->tracks_r([map { ($_ && @$_) ? MIDI::Track->new({ events => [reltime @$_] }) : () } @newtracks]);
	}
	elsif($cmd eq 'program')
	{
		my $tracks = $opus->tracks_r();
		my ($track, $channel, $program) = @arg;
		for my $t(($track eq '*') ? (0..@$tracks-1) : $track)
		{
			my @events = ();
			my %added = ();
			for(abstime $tracks->[$t]->events())
			{
				my $p = $chanpos{$_->[0]};
				if(defined $p)
				{
					my $c = $_->[$p] + 1;
					if($channel eq '*' || $c == $channel)
					{
						next
							if $_->[0] eq 'patch_change';
						if(!$added{$t}{$c})
						{
							push @events, ['patch_change', $_->[1], $c-1, $program-1]
								if $program;
							$added{$t}{$c} = 1;
						}
					}
				}
				push @events, $_;
			}
			$tracks->[$t]->events_r([reltime @events]);
		}
	}
	elsif($cmd eq 'control')
	{
		my $tracks = $opus->tracks_r();
		my ($track, $channel, $control, $value) = @arg;
		for my $t(($track eq '*') ? (0..@$tracks-1) : $track)
		{
			my @events = ();
			my %added = ();
			for(abstime $tracks->[$t]->events())
			{
				my $p = $chanpos{$_->[0]};
				if(defined $p)
				{
					my $c = $_->[$p] + 1;
					if($channel eq '*' || $c == $channel)
					{
						next
							if $_->[0] eq 'control_change' && $_->[3] == $control;
						if(!$added{$t}{$c})
						{
							push @events, ['control_change', $_->[1], $c-1, $control, $value]
								if $value ne '';
							$added{$t}{$c} = 1;
						}
					}
				}
				push @events, $_;
			}
			$tracks->[$t]->events_r([reltime @events]);
		}
	}
	elsif($cmd eq 'transpose')
	{
		my $tracks = $opus->tracks_r();
		my ($track, $channel, $delta) = @arg;
		for(($track eq '*') ? (0..@$tracks-1) : $track)
		{
			for($tracks->[$_]->events())
			{
				my $p = $chanpos{$_->[0]};
				if(defined $p)
				{
					my $c = $_->[$p] + 1;
					if($channel eq '*' ? $c != 10 : $c == $channel)
					{
						if($_->[0] eq 'note_on' || $_->[0] eq 'note_off')
						{
							$_->[3] += $delta;
						}
					}
				}
			}
		}
	}
	elsif($cmd eq 'channel')
	{
		my $tracks = $opus->tracks_r();
		my ($track, %chanmap) = @arg;
		for(($track eq '*') ? (0..@$tracks-1) : $track)
		{
			my @events = ();
			for(abstime $tracks->[$_]->events())
			{
				my $p = $chanpos{$_->[0]};
				if(!defined $p)
				{
					push @events, $_;
					next;
				}
				my $c = $_->[$p] + 1;
				my @c = split /,/, ($chanmap{$c} // $chanmap{'*'} // $c);
				for my $c(@c) {
					next
						if $c == 0; # kill by setting channel to 0
					my @copy = @$_;
					$copy[$p] = $c - 1;
					push @events, \@copy;
				}
			}
			$tracks->[$_]->events_r([reltime @events]);
		}
	}
	elsif($cmd eq 'percussion')
	{
		my $tracks = $opus->tracks_r();
		my ($track, $channel, %map) = @arg;
		for(($track eq '*') ? (0..@$tracks-1) : $track)
		{
			my @events = ();
			for(abstime $tracks->[$_]->events())
			{
				my $p = $chanpos{$_->[0]};
				if(defined $p)
				{
					my $c = $_->[$p] + 1;
					if($channel eq '*' || $c == $channel)
					{
						if($_->[0] eq 'note_on' || $_->[0] eq 'note_off')
						{
							if(length $map{$_->[3]})
							{
								$_->[3] = $map{$_->[3]};
							}
							elsif(exists $map{$_->[3]})
							{
								next;
							}
						}
					}
				}
				push @events, $_;
			}
			$tracks->[$_]->events_r([reltime @events]);
		}
	}
	elsif($cmd eq 'tracks')
	{
		my $tracks = $opus->tracks_r();
		if(@arg)
		{
			my %taken = ();
			my @t = ();
			my $force = 0;
			for(@arg)
			{
				if($_ eq '--force')
				{
					$force = 1;
					next;
				}
				next if $taken{$_}++ and not $force;
				push @t, $tracks->[$_];
			}
			$opus->tracks_r(\@t);
		}
		else
		{
			for(0..@$tracks-1)
			{
				print "Track $_:";
				my $name = undef;
				my %channels = ();
				my $notes = 0;
				my %notehash = ();
				my $t = 0;
				my $events = 0;
				my $min = undef;
				my $max = undef;
				for($tracks->[$_]->events())
				{
					++$events;
					$_->[0] = 'note_off' if $_->[0] eq 'note_on' and $_->[4] == 0;
					$t += $_->[1];
					my $p = $chanpos{$_->[0]};
					if(defined $p)
					{
						my $c = $_->[$p] + 1;
						$channels{$c} //= {};
						if($_->[0] eq 'patch_change')
						{
							++$channels{$c}{$_->[3]};
						}
					}
					++$notes if $_->[0] eq 'note_on';
					$notehash{$_->[2]}{$_->[3]} = $t if $_->[0] eq 'note_on';
					$notehash{$_->[2]}{$_->[3]} = undef if $_->[0] eq 'note_off';
					$name = $_->[2] if $_->[0] eq 'track_name';
					if($_->[0] eq 'note_on')
					{
						$min = $_->[3] if !defined $min || $_->[3] < $min;
						$max = $_->[3] if !defined $max || $_->[3] > $max;
					}
				}
				my $channels = join " ", map { sprintf "%s(%s)", $_, join ",", sort { $a <=> $b } keys %{$channels{$_}} } sort { $a <=> $b } keys %channels;
				my @stuck = ();
				while(my ($k1, $v1) = each %notehash)
				{
					while(my ($k2, $v2) = each %$v1)
					{
						push @stuck, sprintf "%d:%d@%.1f%%", $k1+1, $k2, $v2 * 100.0 / $t
							if defined $v2;
					}
				}
				print " $name" if defined $name;
				print " (channel $channels)" if $channels ne "";
				print " ($events events)" if $events;
				print " ($notes notes [$min-$max])" if $notes;
				print " (notes @stuck stuck)" if @stuck;
				print "\n";
			}
		}
	}
	elsif($cmd eq 'save')
	{
		$opus->write_to_file($arg[0]);
	}
	else
	{
		print "Unknown command, allowed commands:\n";
		print "  clean\n";
		print "  dump\n";
		print "  ticks [value]\n";
		print "  retrack\n";
		print "  program <track|*> <channel|*> <program (1-based)>\n";
		print "  control <track|*> <channel|*> <control> <value>\n";
		print "  transpose <track|*> <channel|*> <delta>\n";
		print "  channel <track|*> <channel|*> <channel> [<channel> <channel> ...]\n";
		print "  percussion <track|*> <channel|*> <from> <to> [<from> <to> ...]\n";
		print "  tracks [trackno] [trackno] ...\n";
		print "  save <filename.mid>\n";
	}
	print "Done with: $cmd @arg\n";
}
