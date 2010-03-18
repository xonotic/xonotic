# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - votestop.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

# This plugin will stop an ongoing vote when the person who called it leaves. Edit the options below
# to disallow votes after certain events.

{ my %vs = (
	mapstart => 90, # can't call mapchange votes for this amount of seconds after mapstart
	connected => 120, # can't call votes when you just joined the server
	minplayers => 2, # minimal amount of players for this script to work.
);

$store{plugin_votestop} = \%vs; }

# add a dependency on joinsparts.pl
if (defined %config && $config{plugins} !~ m/joinsparts.pl /gi) {
	die "votestop.pl depends on joinsparts.pl but it appears to not be loaded.";
}

sub out($$@);

sub time_to_seconds {
	my @ar = split /:/, $_[0];
	return ($ar[0] * 60 * 60) + ($ar[1] * 60) + $ar[2];
}

[ dp => q{:vote:vcall:(\d+):(.*)} => sub {
	my ($id, $command) = @_;
	$command = color_dp2irc $command;
	my $vs = $store{plugin_votestop};
	
	# use joinsparts for player check
	return 0 unless ($id && get_player_count() >= $vs->{minplayers});
	
	my $slot = $store{"playerslot_byid_$id"};
	if ($vs->{mapstart} && (time() - $store{map_starttime}) < $vs->{mapstart}) {
		if ($command =~ m/(endmatch|restart|gotomap|chmap)/gi) {
			$vs->{vstopignore} = 1;
			out dp => 0, "sv_cmd vote stop";
			out irc => 0, "PRIVMSG $config{irc_channel} :* vote \00304$command\017 by " . $store{"playernick_byid_$id"} .
				"\017 was rejected because the map hasn't been played long enough";
				
			out dp => 0, "tell #$slot your vote was rejected because this map only just started.";
			
			return -1;
		}
	}
	
	my $time = time_to_seconds $store{"playerslot_$slot"}->{'time'};
	$time ||= 0;
	if ($vs->{connected} && $time < $vs->{connected}) {
		$vs->{vstopignore} = 1;
		out dp => 0, "sv_cmd vote stop";
		out irc => 0, "PRIVMSG $config{irc_channel} :* vote \00304$command\017 by " . $store{"playernick_byid_$id"} .
			"\017 was rejected because he isn't connected long enough";
			
		out dp => 0, "tell #$slot your vote was rejected because you just joined the server.";
			
		return -1;
	}
	
	$vs->{currentvote} = $id;
	return 0;
} ],

[ dp => q{:vote:v(yes|no|timeout|stop):.*} => sub {
	my ($cmd) = @_;
	$store{plugin_votestop}->{currentvote} = undef;
	my $vs = $store{plugin_votestop};
	
	if ($cmd eq 'stop' && $vs->{vstopignore}) {
		$vs->{vstopignore} = undef;
		return -1;
	}
	
	return 0;
} ],

[ dp => q{:part:(\d+)} => sub {
	my ($id) = @_;
	my $vs = $store{plugin_votestop};
	
	if (defined $store{plugin_votestop}->{currentvote} && $id == $store{plugin_votestop}->{currentvote}) {
		$vs->{vstopignore} = 1;
		out dp => 0, "sv_cmd vote stop";
		out irc => 0, "PRIVMSG $config{irc_channel} :* vote \00304$command\017 by " . $store{"playernick_byid_$id"} .
			"\017 was stopped because he left the server";
	}
	
	return 0;
} ],

[ dp => q{:gamestart:(.*):[0-9.]*} => sub {
	my $vs = $store{plugin_votestop};
	
	if (defined $store{plugin_votestop}->{currentvote}) {
		out dp => 0, "sv_cmd vote stop";
		$store{plugin_votestop}->{currentvote} = undef;
		$vs->{vstopignore} = undef;
	}
	
	return 0;
} ],
