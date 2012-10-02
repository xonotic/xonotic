#!/usr/bin/perl

# converter from Type 1 MIDI files to CFG files that control bots with the Tuba and other weapons for percussion (requires g_weaponarena all)

use strict;
use warnings;
use MIDI;
use MIDI::Opus;
use Storable;

# workaround for possible refire time problems
use constant SYS_TICRATE => 0.033333;
#use constant SYS_TICRATE => 0;

use constant MIDI_FIRST_NONCHANNEL => 17;
use constant MIDI_DRUMS_CHANNEL => 10;
use constant TEXT_EVENT_CHANNEL => -1;

die "Usage: $0 filename.conf midifile1 transpose1 midifile2 transpose2 ..."
	unless @ARGV > 1 and @ARGV % 2;

my $timeoffset_preinit = 2;
my $timeoffset_postinit = 2;
my $timeoffset_predone = 2;
my $timeoffset_postdone = 2;
my $timeoffset_preintermission = 2;
my $timeoffset_postintermission = 2;
my $time_forgetfulness = 1.5;
my %lists = ();
my %listindexes = ();

my ($config, @midilist) = @ARGV;

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
		s/\s*\/\/.*//;
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
				$currentbot->{transpose} ||= 0;
				$currentbot->{transpose} += $1;
			}
			elsif(/^channels (.*)/)
			{
				$currentbot->{channels} = { map { $_ => 1 } split /\s+/, $1 };
			}
			elsif(/^programs (.*)/)
			{
				$currentbot->{programs} = { map { $_ => 1 } split /\s+/, $1 };
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
			elsif(/^text (.*)$/)
			{
				$super = $currentbot->{text}->{$1};
				$currentbot->{text}->{$1} = $appendref = [];
			}
			else
			{
				print STDERR "unknown command: $_\n";
			}
		}
		elsif(/^bot (.*)/)
		{
			$currentbot = ($bots{$1} ||= {count => 0});
		}
		elsif(/^raw (.*)/)
		{
			$precommands .= "$1\n";
		}
		elsif(/^timeoffset_preinit (.*)/)
		{
			$timeoffset_preinit = $1;
		}
		elsif(/^timeoffset_postinit (.*)/)
		{
			$timeoffset_postinit = $1;
		}
		elsif(/^timeoffset_predone (.*)/)
		{
			$timeoffset_predone = $1;
		}
		elsif(/^timeoffset_postdone (.*)/)
		{
			$timeoffset_postdone = $1;
		}
		elsif(/^timeoffset_preintermission (.*)/)
		{
			$timeoffset_preintermission = $1;
		}
		elsif(/^timeoffset_postintermission (.*)/)
		{
			$timeoffset_postintermission = $1;
		}
		elsif(/^time_forgetfulness (.*)/)
		{
			$time_forgetfulness = $1;
		}
		elsif(/^list (.*?) (.*)/)
		{
			$lists{$1} = [split / /, $2];
			$listindexes{$1} = 0;
		}
		else
		{
			print STDERR "unknown command: $_\n";
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


# returns: ($mintime, $maxtime, $busytime)
sub busybot_cmd_bot_cmdinfo(@)
{
	my (@commands) = @_;

	my $mintime = undef;
	my $maxtime = undef;
	my $busytime = undef;

	for(@commands)
	{
		if($_->[0] eq 'time')
		{
			$mintime = $_->[1]
				if not defined $mintime or $_->[1] < $mintime;
			$maxtime = $_->[1] + SYS_TICRATE
				if not defined $maxtime or $_->[1] + SYS_TICRATE > $maxtime;
		}
		elsif($_->[0] eq 'busy')
		{
			$busytime = $_->[1] + SYS_TICRATE;
		}
	}

	return ($mintime, $maxtime, $busytime);
}

sub busybot_cmd_bot_matchtime($$$@)
{
	my ($bot, $targettime, $targetbusytime, @commands) = @_;

	# I want to execute @commands so that I am free on $targettime and $targetbusytime
	# when do I execute it then?

	my ($mintime, $maxtime, $busytime) = busybot_cmd_bot_cmdinfo @commands;

	my $tstart_max = defined $maxtime ? $targettime - $maxtime : $targettime;
	my $tstart_busy = defined $busytime ? $targetbusytime - $busytime : $targettime;

	return $tstart_max < $tstart_busy ? $tstart_max : $tstart_busy;
}

# TODO function to find out whether, and when, to insert a command before another command to make it possible
# (note-off before note-on)

sub busybot_cmd_bot_test($$$@)
{
	my ($bot, $time, $force, @commands) = @_;

	my $bottime = defined $bot->{timer} ? $bot->{timer} : -1;
	my $botbusytime = defined $bot->{busytimer} ? $bot->{busytimer} : -1;

	my ($mintime, $maxtime, $busytime) = busybot_cmd_bot_cmdinfo @commands;

	if($time < $botbusytime)
	{
		warn "FORCE: $time < $botbusytime"
			if $force;
		return $force;
	}
	
	if(defined $mintime and $time + $mintime < $bottime)
	{
		warn "FORCE: $time + $mintime < $bottime"
			if $force;
		return $force;
	}
	
	return 1;
}

sub buildstring(@)
{
	return
		join " ",
		map
		{
			$_ =~ /^\@(.*)$/
				? do { $lists{$1}[$listindexes{$1}++ % @{$lists{$1}}]; }
				: $_
		}
		@_;
}

sub busybot_cmd_bot_execute($$@)
{
	my ($bot, $time, @commands) = @_;

	for(@commands)
	{
		if($_->[0] eq 'time')
		{
			$commands .= sprintf "sv_cmd bot_cmd %d wait_until %f\n", $bot->{id}, $time + $_->[1];
			if($bot->{timer} > $time + $_->[1] + SYS_TICRATE)
			{
				#use Carp; carp "Negative wait: $bot->{timer} <= @{[$time + $_->[1] + SYS_TICRATE]}";
			}
			$bot->{timer} = $time + $_->[1] + SYS_TICRATE;
		}
		elsif($_->[0] eq 'busy')
		{
			$bot->{busytimer} = $time + $_->[1] + SYS_TICRATE;
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
			$commands .= sprintf "sv_cmd bot_cmd %d %s\n", $bot->{id}, buildstring @{$_}[1..@$_-1];
		}
		elsif($_->[0] eq 'aim_random')
		{
			$commands .= sprintf "sv_cmd bot_cmd %d aim \"%f 0 %f\"\n", $bot->{id}, $_->[1] + rand($_->[2] - $_->[1]), $_->[3];
		}
		elsif($_->[0] eq 'barrier')
		{
			$commands .= sprintf "sv_cmd bot_cmd %d barrier\n", $bot->{id};
			$bot->{timer} = $bot->{busytimer} = 0;
			undef $bot->{lastuse};
		}
		elsif($_->[0] eq 'raw')
		{
			$commands .= sprintf "%s\n", buildstring @{$_}[1..@$_-1];
		}
		else
		{
			warn "Invalid command: @$_";
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
		if not $bot->{busy};
	my ($busychannel, $busynote, $cmds) = @{$bot->{busy}};
	return 1
		if not defined $cmds; # note off cannot fail
	die "Wrong note-off?!?"
		if $busychannel != $channel || $busynote ne $note;
	$bot->{busy} = undef;

	my $t = $time + $notetime;
	my ($mintime, $maxtime, $busytime) = busybot_cmd_bot_cmdinfo @$cmds;

	# perform note-off "as soon as we can"
	$t = $bot->{busytimer}
		if $t < $bot->{busytimer};
	$t = $bot->{timer} - $mintime
		if $t < $bot->{timer} - $mintime;

	busybot_cmd_bot_execute $bot, $t, @$cmds; 
	return 1;
}

sub busybot_get_cmds_bot($$$)
{
	my ($bot, $channel, $note) = @_;
	my ($k0, $k1, $cmds, $cmds_off) = (undef, undef, undef, undef);
	if($channel == TEXT_EVENT_CHANNEL)
	{
		# vocals
		$note =~ /^([^:]*):(.*)$/;
		my $name = $1;
		my $data = $2;
		$cmds = $bot->{text}->{$name};
		if(defined $cmds)
		{
			$cmds = [ map { [ map { $_ eq '%s' ? $data : $_ } @$_ ] } @$cmds ];
		}
		$k0 = "text";
		$k1 = $name;
	}
	elsif($channel == 10)
	{
		# percussion
		$cmds = $bot->{percussion}->{$note};
		$k0 = "percussion";
		$k1 = $note;
	}
	else
	{
		# music
		$cmds = $bot->{notes_on}->{$note - ($bot->{transpose} || 0) - $transpose};
		$cmds_off = $bot->{notes_off}->{$note - ($bot->{transpose} || 0) - $transpose};
		$k0 = "note";
		$k1 = $note - ($bot->{transpose} || 0) - $transpose;
	}
	return ($cmds, $cmds_off, $k0, $k1);
}

sub busybot_note_on_bot($$$$$$$)
{
	my ($bot, $time, $channel, $program, $note, $init, $force) = @_;

	return -1 # I won't play on this channel
		if defined $bot->{channels} and not $bot->{channels}->{$channel};
	return -1 # I won't play this program
		if defined $bot->{programs} and not $bot->{programs}->{$program};

	my ($cmds, $cmds_off, $k0, $k1) = busybot_get_cmds_bot($bot, $channel, $note);

	return -1 # I won't play this note
		if not defined $cmds;
	return 0
		if $bot->{busy};
	#print STDERR "note on $bot:$time:$channel:$note\n";
	if($init)
	{
		return 0
			if not busybot_cmd_bot_test $bot, $time + $notetime, $force, @$cmds; 
		busybot_cmd_bot_execute $bot, 0, ['cmd', 'wait', $timeoffset_preinit];
		busybot_cmd_bot_execute $bot, 0, ['barrier'];
		busybot_cmd_bot_execute $bot, 0, @{$bot->{init}}
			if @{$bot->{init}};
		busybot_cmd_bot_execute $bot, 0, ['barrier'];
		for(1..$intermissions)
		{
			busybot_intermission_bot $bot;
		}
		# we always did a barrier, so we know this works
		busybot_cmd_bot_execute $bot, $time + $notetime, @$cmds; 
	}
	else
	{
		return 0
			if not busybot_cmd_bot_test $bot, $time + $notetime, $force, @$cmds; 
		busybot_cmd_bot_execute $bot, $time + $notetime, @$cmds; 
	}
	if(defined $cmds_off)
	{
		$bot->{busy} = [$channel, $note, $cmds_off];
	}
	++$bot->{seen}{$k0}{$k1};

	if(($bot->{lastuse} // -666) >= $time - $time_forgetfulness && $channel == $bot->{lastchannel})
	{
		$bot->{lastchannelsequence} += 1;
	}
	else
	{
		$bot->{lastchannelsequence} = 1;
	}
	$bot->{lastuse} = $time;
	$bot->{lastchannel} = $channel;

#	print STDERR "$time $bot->{id} $channel:$note\n"
#		if $channel == 11;

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

#	print STDERR "note off $time:$channel:$note\n";

	if(my $bot = $notechannelbots{$channel}{$note})
	{
		busybot_note_off_bot $bot, $time, $channel, $note;
		delete $notechannelbots{$channel}{$note};
		return 1;
	}

	return 0;
}

sub botsort($$$$@)
{
	my ($time, $channel, $program, $note, @bots) = @_;
	return
		map
		{
			$_->[0]
		}
		sort
		{
			$b->[1] <=> $a->[1]
			or
			($a->[0]->{lastuse} // -666) <=> ($b->[0]->{lastuse} // -666)
			or
			$a->[2] <=> $b->[2]
		}
		map
		{
			my $q = 0;
			if($channel != 10) # percussion just should do round robin
			{
				if(($_->{lastuse} // -666) >= $time - $time_forgetfulness)
				{
					if($channel == $_->{lastchannel})
					{
						$q += $_->{lastchannelsequence};
					}
					else
					{
						# better leave this one alone
						$q -= $_->{lastchannelsequence};
					}
				}
			}
			[$_, $q, rand]
		}
		@bots;
}

sub busybot_note_on($$$$)
{
	my ($time, $channel, $program, $note) = @_;

	if($notechannelbots{$channel}{$note})
	{
		print STDERR "THIS SHOULD NEVER HAPPEN\n";
		busybot_note_off $time, $channel, $note;
	}

#	print STDERR "note on $time:$channel:$note\n";

	my $overflow = 0;

	my @epicfailbots = ();

	for(botsort $time, $channel, $program, $note, @busybots_allocated)
	{
		my $canplay = busybot_note_on_bot $_, $time, $channel, $program, $note, 0, 0;
		if($canplay > 0)
		{
			$notechannelbots{$channel}{$note} = $_;
			return 1;
		}
		push @epicfailbots, $_
			if $canplay == 0;
		# wrong
	}

	my $needalloc = 0;

	for(unsort keys %$busybots)
	{
		next if $busybots->{$_}->{count} <= 0;
		my $bot = Storable::dclone $busybots->{$_};
		$bot->{id} = @busybots_allocated + 1;
		$bot->{classname} = $_;
		my $canplay = busybot_note_on_bot $bot, $time, $channel, $program, $note, 1, 0;
		if($canplay > 0)
		{
			if($noalloc)
			{
				$needalloc = 1;
			}
			else
			{
				--$busybots->{$_}->{count};
				$notechannelbots{$channel}{$note} = $bot;
				push @busybots_allocated, $bot;
				return 1;
			}
		}
		die "Fresh bot cannot play stuff"
			if $canplay == 0;
	}

	if(@epicfailbots)
	{
		# we cannot add a new bot to play this
		# we could try finding a bot that could play this, and force him to stop the note!

		my @candidates = (); # contains: [$bot, $score, $offtime]

		# put in all currently busy bots that COULD play this, if they did a note-off first
		for my $bot(@epicfailbots)
		{
			next
				if $busybots->{$bot->{classname}}->{count} != 0;
			next
				unless $bot->{busy};
			my ($busy_chan, $busy_note, $busy_cmds_off) = @{$bot->{busy}};
			next
				unless $busy_cmds_off;
			my ($cmds, $cmds_off, $k0, $k1) = busybot_get_cmds_bot $bot, $channel, $note;
			next
				unless $cmds;
			my ($mintime, $maxtime, $busytime) = busybot_cmd_bot_cmdinfo @$cmds;
			my ($mintime_off, $maxtime_off, $busytime_off) = busybot_cmd_bot_cmdinfo @$busy_cmds_off;

			my $noteofftime = busybot_cmd_bot_matchtime $bot, $time + $notetime + $mintime, $time + $notetime, @$busy_cmds_off;
			next
				if $noteofftime < $bot->{busytimer};
			next
				if $noteofftime + $mintime_off < $bot->{timer};

			my $score = 0;
			# prefer turning off long notes
			$score +=  100 * ($noteofftime - $bot->{timer});
			# prefer turning off low notes
			$score +=    1 * (-$note);
			# prefer turning off notes that already play on another channel
			$score += 1000 * (grep { $_ != $busy_chan && $notechannelbots{$_}{$busy_note} && $notechannelbots{$_}{$busy_note}{busy} } keys %notechannelbots);

			push @candidates, [$bot, $score, $noteofftime];
		}

		# we found one?

		if(@candidates)
		{
			@candidates = sort { $a->[1] <=> $b->[1] } @candidates;
			my ($bot, $score, $offtime) = @{(pop @candidates)};
			my $oldchan = $bot->{busy}->[0];
			my $oldnote = $bot->{busy}->[1];
			busybot_note_off $offtime - $notetime, $oldchan, $oldnote;
			my $canplay = busybot_note_on_bot $bot, $time, $channel, $program, $note, 0, 1;
			die "Canplay but not?"
				if $canplay <= 0;
			warn "Made $channel:$note play by stopping $oldchan:$oldnote";
			$notechannelbots{$channel}{$note} = $bot;
			return 1;
		}
	}

	die "noalloc\n"
		if $needalloc;

	if(@epicfailbots)
	{
		warn "Not enough bots to play this (when playing $channel:$note)";
#		for(@epicfailbots)
#		{
#			my $b = $_->{busy};
#			warn "$_->{classname} -> @{[$b ? qq{$b->[0]:$b->[1]} : 'none']} @{[$_->{timer} - $notetime]} ($time)\n";
#		}
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
			next
				if $command eq 'text_event' && $data[0] !~ /:/;
			push @allmidievents, [$command, $tick, $sequence++, $track, @data];
		}
	}

	if(open my $fh, "$filename.vocals")
	{
		my $scale = 1;
		my $shift = 0;
		for(<$fh>)
		{
			chomp;
			my ($tick, $file) = split /\s+/, $_;
			if($tick eq 'scale')
			{
				$scale = $file;
			}
			elsif($tick eq 'shift')
			{
				$shift = $file;
			}
			else
			{
				push @allmidievents, ['text_event', $tick * $scale + $shift, $sequence++, -1, "vocals:$file"];
			}
		}
	}

	# HACK for broken rosegarden export: put patch changes first by clearing their sequence number
	for(@allmidievents)
	{
		if($_->[0] eq 'patch_change')
		{
			$_->[2] = -1;
		}
	}

	# sort events
	@allmidievents = sort { $a->[1] <=> $b->[1] or $a->[2] <=> $b->[2] } @allmidievents;

	# find the first interesting event
	my $shift = [grep { $_->[0] eq 'note_on' || $_->[0] eq 'text_event' } @allmidievents]->[0][1];
	die "No notes!"
		unless defined $shift;

	# shift times by first event, no boring waiting
	$_->[0] = ($_->[0] < $shift ? 0 : $_->[0] - $shift) for @tempi;
	$_->[1] = ($_->[1] < $shift ? 0 : $_->[1] - $shift) for @allmidievents;

	# fix event list

	my %midinotes = ();
	my $notes_stuck = 0;
	my %notes_seen = ();
	my %programs = ();
	my $t = 0;
	my %sustain = ();

	my $note_on = sub
	{
		my ($ev) = @_;
		my $chan = $ev->[4] + 1;
		++$notes_seen{$chan}{($programs{$chan} || 1)}{$ev->[5]};
		if($midinotes{$chan}{$ev->[5]})
		{
			--$notes_stuck;
			busybot_note_off($t - SYS_TICRATE - 0.001, $chan, $ev->[5]);
		}
		busybot_note_on($t, $chan, $programs{$chan} || 1, $ev->[5]);
		++$notes_stuck;
		$midinotes{$chan}{$ev->[5]} = 1;
	};

	my $note_off = sub
	{
		my ($ev) = @_;
		my $chan = $ev->[4] + 1;
		if(exists $sustain{$chan})
		{
			push @{$sustain{$chan}}, $ev;
			return;
		}
		if($midinotes{$chan}{$ev->[5]})
		{
			--$notes_stuck;
			busybot_note_off($t - SYS_TICRATE - 0.001, $chan, $ev->[5]);
		}
		$midinotes{$chan}{$ev->[5]} = 0;
	};

	my $text_event = sub
	{
		my ($ev) = @_;

		my $chan = TEXT_EVENT_CHANNEL;

		busybot_note_on($t, TEXT_EVENT_CHANNEL, -1, $ev->[4]);
		busybot_note_off($t, TEXT_EVENT_CHANNEL, $ev->[4]);
	};

	my $patch_change = sub
	{
		my ($ev) = @_;
		my $chan = $ev->[4] + 1;
		my $program = $ev->[5] + 1;
		$programs{$chan} = $program;
	};

	my $sustain_change = sub
	{
		my ($ev) = @_;
		my $chan = $ev->[4] + 1;
		if($ev->[6] == 0)
		{
			# release all currently not pressed notes
			my $s = $sustain{$chan};
			delete $sustain{$chan};
			for(@{($s || [])})
			{
				$note_off->($_);
			}
		}
		else
		{
			# no more note-off
			$sustain{$chan} = [];
		}
	};

	for(@allmidievents)
	{
		$t = $tick2sec->($_->[1]);
		# my $track = $_->[3];
		if($_->[0] eq 'note_on')
		{
			$note_on->($_);
		}
		elsif($_->[0] eq 'note_off')
		{
			$note_off->($_);
		}
		elsif($_->[0] eq 'text_event')
		{
			$text_event->($_);
		}
		elsif($_->[0] eq 'patch_change')
		{
			$patch_change->($_);
		}
		elsif($_->[0] eq 'control_change' && $_->[5] == 64) # sustain pedal
		{
			$sustain_change->($_);
		}
	}

	# fake events for releasing pedal
	for(keys %sustain)
	{
		$sustain_change->(['control_change', $t, undef, undef, $_ - 1, 64, 0]);
	}

	print STDERR "For file $filename:\n";
	print STDERR "  Stuck notes: $notes_stuck\n";

	for my $testtranspose(-127..127)
	{
		my $toohigh = 0;
		my $toolow = 0;
		my $good = 0;
		for my $channel(sort keys %notes_seen)
		{
			next if $channel == 10;
			for my $program(sort keys %{$notes_seen{$channel}})
			{
				for my $note(sort keys %{$notes_seen{$channel}{$program}})
				{
					my $cnt = $notes_seen{$channel}{$program}{$note};
					my $votehigh = 0;
					my $votelow = 0;
					my $votegood = 0;
					for(@busybots_allocated, grep { $_->{count} > 0 } values %$busybots)
					{
						next # I won't play on this channel
							if defined $_->{channels} and not $_->{channels}->{$channel};
						next # I won't play this program
							if defined $_->{programs} and not $_->{programs}->{$program};
						my $transposed = $note - ($_->{transpose} || 0) - $testtranspose;
						if(exists $_->{notes_on}{$transposed})
						{
							++$votegood;
						}
						else
						{
							++$votehigh if $transposed >= 0;
							++$votelow if $transposed < 0;
						}
					}
					if($votegood)
					{
						$good += $cnt;
					}
					elsif($votelow >= $votehigh)
					{
						$toolow += $cnt;
					}
					else
					{
						$toohigh += $cnt;
					}
				}
			}
		}
		next if !$toohigh != !$toolow;
		print STDERR "  Transpose $testtranspose: $toohigh too high, $toolow too low, $good good\n";
	}

	for my $program(sort keys %{$notes_seen{10}})
	{
		for my $note(sort keys %{$notes_seen{10}{$program}})
		{
			my $cnt = $notes_seen{10}{$program}{$note};
			my $votegood = 0;
			for(@busybots_allocated)
			{
				next # I won't play on this channel
					if defined $_->{channels} and not $_->{channels}->{10};
				next # I won't play this program
					if defined $_->{programs} and not $_->{programs}->{$program};
				if(exists $_->{percussion}{$note})
				{
					++$votegood;
				}
			}
			if(!$votegood)
			{
				print STDERR "Failed percussion $note ($cnt times)\n";
			}
		}
	}

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
	my %notehash;
	my %counthash;
	for(@busybots_allocated)
	{
		print STDERR "$_->{id} is a $_->{classname}\n";
		++$counthash{$_->{classname}};
		while(my ($type, $notehash) = each %{$_->{seen}})
		{
			while(my ($k, $v) = each %$notehash)
			{
				$notehash{$_->{classname}}{$type}{$k} += $v;
			}
		}
	}
	for my $cn(sort keys %counthash)
	{
		print STDERR "$counthash{$cn} bots of $cn have played:\n";
		for my $type(sort keys %{$notehash{$cn}})
		{
			for my $note(sort keys %{$notehash{$cn}{$type}})
			{
				my $cnt = $notehash{$cn}{$type}{$note};
				print STDERR "  $type $note ($cnt times)\n";
			}
		}
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
	%listindexes = ();
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
			print "sv_cmd bot_cmd setbots @{[scalar @preallocate_new]}\n";
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
