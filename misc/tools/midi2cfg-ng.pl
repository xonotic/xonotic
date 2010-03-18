#!/usr/bin/perl

# converter from Type 1 MIDI files to CFG files that control bots with the Tuba and other weapons for percussion (requires g_weaponarena all)

use strict;
use warnings;
use MIDI;
use MIDI::Opus;
use Storable;

use constant MIDI_FIRST_NONCHANNEL => 17;
use constant MIDI_DRUMS_CHANNEL => 10;

die "Usage: $0 filename.conf timeoffset_preinit timeoffset_postinit timeoffset_predone timeoffset_postdone timeoffset_preintermission timeoffset_postintermission midifile1 transpose1 midifile2 transpose2 ..."
	unless @ARGV > 7 and @ARGV % 2;
my ($config, $timeoffset_preinit, $timeoffset_postinit, $timeoffset_predone, $timeoffset_postdone, $timeoffset_preintermission, $timeoffset_postintermission, @midilist) = @ARGV;

sub unsort(@)
{
	return map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [$_, rand] } @_;
}

sub override($$);
sub override($$)
{
	my ($dest, $src) = @_;
	if(ref $src eq 'HASH')
	{
		$dest = {}
			if not defined $dest;
		for(keys %$src)
		{
			$dest->{$_} = override $dest->{$_}, $src->{$_};
		}
	}
	elsif(ref $src eq 'ARRAY')
	{
		$dest = []
			if not defined $dest;
		for(@$src)
		{
			push @$dest, override undef, $_;
		}
	}
	elsif(ref $src)
	{
		$dest = Storable::dclone $src;
	}
	else
	{
		$dest = $src;
	}
	return $dest;
}

my $precommands = "";
my $commands = "";
my $busybots;
my @busybots_allocated;
my %notechannelbots;
my $transpose = 0;
my $notetime = undef;
my $lowestnotestart = undef;
my $noalloc = 0;
sub botconfig_read($)
{
	my ($fn) = @_;
	my %bots = ();
	open my $fh, "<", $fn
		or die "<$fn: $!";
	
	my $currentbot = undef;
	my $appendref = undef;
	my $super = undef;
	while(<$fh>)
	{
		chomp;
		s/\s*#.*//;
		next if /^$/;
		if(s/^\t\t//)
		{
			my @cmd = split /\s+/, $_;
			if($cmd[0] eq 'super')
			{
				push @$appendref, @$super
					if $super;
			}
			elsif($cmd[0] eq 'percussion') # simple import
			{
				push @$appendref, @{$currentbot->{percussion}->{$cmd[1]}};
			}
			else
			{
				push @$appendref, \@cmd;
			}
		}
		elsif(s/^\t//)
		{
			if(/^include (.*)/)
			{
				my $base = $bots{$1};
				$currentbot = override $currentbot, $base;
			}
			elsif(/^count (\d+)/)
			{
				$currentbot->{count} = $1;
			}
			elsif(/^transpose (\d+)/)
			{
				$currentbot->{transpose} += $1;
			}
			elsif(/^channels (.*)/)
			{
				$currentbot->{channels} = { map { $_ => 1 } split /\s+/, $1 };
			}
			elsif(/^init$/)
			{
				$super = $currentbot->{init};
				$currentbot->{init} = $appendref = [];
			}
			elsif(/^intermission$/)
			{
				$super = $currentbot->{intermission};
				$currentbot->{intermission} = $appendref = [];
			}
			elsif(/^done$/)
			{
				$super = $currentbot->{done};
				$currentbot->{done} = $appendref = [];
			}
			elsif(/^note on (-?\d+)/)
			{
				$super = $currentbot->{notes_on}->{$1};
				$currentbot->{notes_on}->{$1} = $appendref = [];
			}
			elsif(/^note off (-?\d+)/)
			{
				$super = $currentbot->{notes_off}->{$1};
				$currentbot->{notes_off}->{$1} = $appendref = [];
			}
			elsif(/^percussion (\d+)/)
			{
				$super = $currentbot->{percussion}->{$1};
				$currentbot->{percussion}->{$1} = $appendref = [];
			}
			else
			{
				print "unknown command: $_\n";
			}
		}
		elsif(/^bot (.*)/)
		{
			$currentbot = ($bots{$1} ||= {count => 0, transpose => 0});
		}
		elsif(/^raw (.*)/)
		{
			$precommands .= "$1\n";
		}
		else
		{
			print "unknown command: $_\n";
		}
	}

	for(values %bots)
	{
		for(values %{$_->{notes_on}}, values %{$_->{percussion}})
		{
			my $t = $_->[0]->[0] eq 'time' ? $_->[0]->[1] : 0;
			$lowestnotestart = $t if not defined $lowestnotestart or $t < $lowestnotestart;
		}
	}

	return \%bots;
}
my $busybots_orig = botconfig_read $config;


sub busybot_cmd_bot_test($$@)
{
	my ($bot, $time, @commands) = @_;

	my $bottime = defined $bot->{timer} ? $bot->{timer} : -1;
	my $botbusytime = defined $bot->{busytimer} ? $bot->{busytimer} : -1;

	return 0
		if $time < $botbusytime;
	
	my $mintime = (@commands && ($commands[0]->[0] eq 'time')) ? $commands[0]->[1] : 0;

	return 0
		if $time + $mintime < $bottime;
	
	return 1;
}

sub busybot_cmd_bot_execute($$@)
{
	my ($bot, $time, @commands) = @_;

	for(@commands)
	{
		if($_->[0] eq 'time')
		{
			$commands .= sprintf "sv_cmd bot_cmd %d wait_until %f\n", $bot->{id}, $time + $_->[1];
			$bot->{timer} = $time + $_->[1];
		}
		elsif($_->[0] eq 'busy')
		{
			$bot->{busytimer} = $time + $_->[1];
		}
		elsif($_->[0] eq 'buttons')
		{
			my %buttons_release = %{$bot->{buttons} ||= {}};
			for(@{$_}[1..@$_-1])
			{
				/(.*)\??/ or next;
				delete $buttons_release{$1};
			}
			for(keys %buttons_release)
			{
				$commands .= sprintf "sv_cmd bot_cmd %d releasekey %s\n", $bot->{id}, $_;
				delete $bot->{buttons}->{$_};
			}
			for(@{$_}[1..@$_-1])
			{
				/(.*)(\?)?/ or next;
				defined $2 and next;
				$commands .= sprintf "sv_cmd bot_cmd %d presskey %s\n", $bot->{id}, $_;
				$bot->{buttons}->{$_} = 1;
			}
		}
		elsif($_->[0] eq 'cmd')
		{
			$commands .= sprintf "sv_cmd bot_cmd %d %s\n", $bot->{id}, join " ", @{$_}[1..@$_-1];
		}
		elsif($_->[0] eq 'barrier')
		{
			$commands .= sprintf "sv_cmd bot_cmd %d barrier\n", $bot->{id};
			$bot->{timer} = $bot->{busytimer} = 0;
		}
		elsif($_->[0] eq 'raw')
		{
			$commands .= sprintf "%s\n", join " ", @{$_}[1..@$_-1];
		}
	}

	return 1;
}

my $intermissions = 0;

sub busybot_intermission_bot($)
{
	my ($bot) = @_;
	busybot_cmd_bot_execute $bot, 0, ['cmd', 'wait', $timeoffset_preintermission];
	busybot_cmd_bot_execute $bot, 0, ['barrier'];
	if($bot->{intermission})
	{
		busybot_cmd_bot_execute $bot, 0, @{$bot->{intermission}};
	}
	busybot_cmd_bot_execute $bot, 0, ['barrier'];
	$notetime = $timeoffset_postintermission - $lowestnotestart;
}

#my $busy = 0;
sub busybot_note_off_bot($$$$)
{
	my ($bot, $time, $channel, $note) = @_;
	#print STDERR "note off $bot:$time:$channel:$note\n";
	return 1
		if $channel == 10;
	my $cmds = $bot->{notes_off}->{$note - $bot->{transpose} - $transpose};
	return 1
		if not defined $cmds; # note off cannot fail
	$bot->{busy} = 0;
	#--$busy;
	#print STDERR "BUSY: $busy bots (OFF)\n";
	busybot_cmd_bot_execute $bot, $time + $notetime, @$cmds; 
	return 1;
}

sub busybot_note_on_bot($$$$$)
{
	my ($bot, $time, $channel, $note, $init) = @_;
	return -1 # I won't play on this channel
		if defined $bot->{channels} and not $bot->{channels}->{$channel};
	my $cmds;
	my $cmds_off;
	if($channel == 10)
	{
		$cmds = $bot->{percussion}->{$note};
		$cmds_off = undef;
	}
	else
	{
		$cmds = $bot->{notes_on}->{$note - $bot->{transpose} - $transpose};
		$cmds_off = $bot->{notes_off}->{$note - $bot->{transpose} - $transpose};
	}
	return -1 # I won't play this note
		if not defined $cmds;
	return 0
		if $bot->{busy};
	#print STDERR "note on $bot:$time:$channel:$note\n";
	if($init)
	{
		return 0
			if not busybot_cmd_bot_test $bot, $time + $notetime, @$cmds; 
		busybot_cmd_bot_execute $bot, 0, ['cmd', 'wait', $timeoffset_preinit];
		busybot_cmd_bot_execute $bot, 0, ['barrier'];
		busybot_cmd_bot_execute $bot, 0, @{$bot->{init}}
			if @{$bot->{init}};
		busybot_cmd_bot_execute $bot, 0, ['barrier'];
		for(1..$intermissions)
		{
			busybot_intermission_bot $bot;
		}
		busybot_cmd_bot_execute $bot, $time + $notetime, @$cmds; 
	}
	else
	{
		return 0
			if not busybot_cmd_bot_test $bot, $time + $notetime, @$cmds; 
		busybot_cmd_bot_execute $bot, $time + $notetime, @$cmds; 
	}
	if(defined $cmds and defined $cmds_off)
	{
		$bot->{busy} = 1;
		#++$busy;
		#print STDERR "BUSY: $busy bots (ON)\n";
	}
	return 1;
}

sub busybots_reset()
{
	$busybots = Storable::dclone $busybots_orig;
	@busybots_allocated = ();
	%notechannelbots = ();
	$transpose = 0;
	$notetime = $timeoffset_postinit - $lowestnotestart;
}

sub busybot_note_off($$$)
{
	my ($time, $channel, $note) = @_;

	#print STDERR "note off $time:$channel:$note\n";

	return 0
		if $channel == 10;

	if(my $bot = $notechannelbots{$channel}{$note})
	{
		busybot_note_off_bot $bot, $time, $channel, $note;
		delete $notechannelbots{$channel}{$note};
		return 1;
	}

	return 0;
}

sub busybot_note_on($$$)
{
	my ($time, $channel, $note) = @_;

	if($notechannelbots{$channel}{$note})
	{
		busybot_note_off $time, $channel, $note;
	}

	#print STDERR "note on $time:$channel:$note\n";

	my $overflow = 0;

	for(unsort @busybots_allocated)
	{
		my $canplay = busybot_note_on_bot $_, $time, $channel, $note, 0;
		if($canplay > 0)
		{
			$notechannelbots{$channel}{$note} = $_;
			return 1;
		}
		$overflow = 1
			if $canplay == 0;
		# wrong
	}

	for(unsort keys %$busybots)
	{
		next if $busybots->{$_}->{count} <= 0;
		my $bot = Storable::dclone $busybots->{$_};
		$bot->{id} = @busybots_allocated + 1;
		$bot->{classname} = $_;
		my $canplay = busybot_note_on_bot $bot, $time, $channel, $note, 1;
		if($canplay > 0)
		{
			die "noalloc\n"
				if $noalloc;
			--$busybots->{$_}->{count};
			$notechannelbots{$channel}{$note} = $bot;
			push @busybots_allocated, $bot;
			return 1;
		}
		die "Fresh bot cannot play stuff"
			if $canplay == 0;
	}

	if($overflow)
	{
		warn "Not enough bots to play this (when playing $channel:$note)";
	}
	else
	{
		warn "Note $channel:$note cannot be played by any bot";
	}

	return 0;
}

sub Preallocate(@)
{
	my (@preallocate) = @_;
	busybots_reset();
	for(@preallocate)
	{
		die "Cannot preallocate any more $_ bots"
			if $busybots->{$_}->{count} <= 0;
		my $bot = Storable::dclone $busybots->{$_};
		$bot->{id} = @busybots_allocated + 1;
		$bot->{classname} = $_;
		busybot_cmd_bot_execute $bot, 0, ['cmd', 'wait', $timeoffset_preinit];
		busybot_cmd_bot_execute $bot, 0, ['barrier'];
		busybot_cmd_bot_execute $bot, 0, @{$bot->{init}}
			if @{$bot->{init}};
		busybot_cmd_bot_execute $bot, 0, ['barrier'];
		--$busybots->{$_}->{count};
		push @busybots_allocated, $bot;
	}
}

sub ConvertMIDI($$)
{
	my ($filename, $trans) = @_;
	$transpose = $trans;

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
	my $tick2sec = sub
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
	};

	# merge all to a single track
	my @allmidievents = ();
	my $sequence = 0;
	for my $track(0..@$tracks-1)
	{
		$tick = 0;
		for($tracks->[$track]->events())
		{
			my ($command, $delta, @data) = @$_;
			$command = 'note_off' if $command eq 'note_on' and $data[2] == 0;
			$tick += $delta;
			push @allmidievents, [$command, $tick, $sequence++, $track, @data];
		}
	}
	@allmidievents = sort { $a->[1] <=> $b->[1] or $a->[2] <=> $b->[2] } @allmidievents;

	my %midinotes = ();
	my $note_min = undef;
	my $note_max = undef;
	my $notes_stuck = 0;
	my $t = 0;
	for(@allmidievents)
	{
		$t = $tick2sec->($_->[1]);
		my $track = $_->[3];
		if($_->[0] eq 'note_on')
		{
			my $chan = $_->[4] + 1;
			$note_min = $_->[5]
				if not defined $note_min or $_->[5] < $note_min and $chan != 10;
			$note_max = $_->[5]
				if not defined $note_max or $_->[5] > $note_max and $chan != 10;
			if($midinotes{$chan}{$_->[5]})
			{
				--$notes_stuck;
				busybot_note_off($t, $chan, $_->[5]);
			}
			busybot_note_on($t, $chan, $_->[5]);
			++$notes_stuck;
			$midinotes{$chan}{$_->[5]} = 1;
		}
		elsif($_->[0] eq 'note_off')
		{
			my $chan = $_->[4] + 1;
			if($midinotes{$chan}{$_->[5]})
			{
				--$notes_stuck;
				busybot_note_off($t, $chan, $_->[5]);
			}
			$midinotes{$chan}{$_->[5]} = 0;
		}
	}

	print STDERR "For file $filename:\n";
	print STDERR "  Range of notes: $note_min .. $note_max\n";
	print STDERR "  Safe transpose range: @{[$note_max - 19]} .. @{[$note_min + 13]}\n";
	print STDERR "  Unsafe transpose range: @{[$note_max - 27]} .. @{[$note_min + 18]}\n";
	print STDERR "  Stuck notes: $notes_stuck\n";

	while(my ($k1, $v1) = each %midinotes)
	{
		while(my ($k2, $v2) = each %$v1)
		{
			busybot_note_off($t, $k1, $k2);
		}
	}

	for(@busybots_allocated)
	{
		busybot_intermission_bot $_;
	}
	++$intermissions;
}

sub Deallocate()
{
	print STDERR "Bots allocated:\n";
	for(@busybots_allocated)
	{
		print STDERR "$_->{id} is a $_->{classname}\n";
	}
	for(@busybots_allocated)
	{
		busybot_cmd_bot_execute $_, 0, ['cmd', 'wait', $timeoffset_predone];
		busybot_cmd_bot_execute $_, 0, ['barrier'];
		if($_->{done})
		{
			busybot_cmd_bot_execute $_, 0, @{$_->{done}};
		}
		busybot_cmd_bot_execute $_, 0, ['cmd', 'wait', $timeoffset_postdone];
		busybot_cmd_bot_execute $_, 0, ['barrier'];
	}
}

my @preallocate = ();
$noalloc = 0;
for(;;)
{
	$commands = "";
	eval
	{
		Preallocate(@preallocate);
		my @l = @midilist;
		while(@l)
		{
			my $filename = shift @l;
			my $transpose = shift @l;
			ConvertMIDI($filename, $transpose);
		}
		Deallocate();
		my @preallocate_new = map { $_->{classname} } @busybots_allocated;
		if(@preallocate_new == @preallocate)
		{
			print "$precommands$commands";
			exit 0;
		}
		@preallocate = @preallocate_new;
		$noalloc = 1;
		1;
	} or do {
		die "$@"
			unless $@ eq "noalloc\n";
	};
}
