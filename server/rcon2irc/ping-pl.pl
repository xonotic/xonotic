# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - ping-pl.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.
# Don't forget to edit the options below to suit your needs.

# This script monitors players ping and packet loss, people with really large values here are 
# lagging a lot, and this lag appears to other players as well as seeing the lagging player move
# with lots of stutter. Bare in mind that even those of us on very good connections may lose a
# packet or have a high ping every once in the while.
# PLEASE CHOOSE SANE VALUES HERE !!!

{ my %pp = (
	max_ping => 350,
	max_pl => 10,
	warn_player => 1, # send a tell command to the player to notify of bad connection (0 or 1)
	warn_irc => 1, # send a warning to irc to notify that a player has a bad connection (0 or 1)
	warnings => 3, # how many times must ping/pl exceed the limit before a warning
	kick => 0, # how many times must ping/pl exceed the limit before a kick (0 to disable)
	timeframe => 20, # minutes until a count is forgotten
	warnmsg => 'You are having connection problems, causing you to lag - please fix them',
	kickmsg => 'You are getting kicked for having connection problems.'
);

$store{plugin_ping-pl} = \%pp; }

sub out($$@);

# Check users ping and packet loss
[ dp => q{\^\d(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(-?\d+)\s+\#(\d+)\s+\^\d(.*)} => sub {
	my ($ip, $pl, $ping, $time, $frags, $no, $name) = ($1, $2, $3, $4, $5, $6, $7);
	my $id = $store{"playerid_byslot_$no"};
	return 0 unless ( defined $id );
	return 0 if ($frags == -666 || $ip eq 'bot');
	my $pp = $store{plugin_ping-pl};

	#does the player violate one of our limits?
	my $warn = 0;
	if ($ping >= $pp->{max_ping} || $pl >= $pp->{max_pl}) {
		#add a violation
		push @{ $pp->{"violation_$id"} }, time();
		$warn = 1;
	}

	#maybe we need to clear the oldest violation
	shift @{ $pp->{"violation_$id"} } if (defined ${ $pp->{"violation_$id"} }[0] && (${ $pp->{"violation_$id"} }[0] + (60 * $pp->{timeframe})) <= time());

	#do we have to kick the user?
	if ((scalar @{ $pp->{"violation_$id"} }) >= $pp->{kick} && $pp->{kick} > 0) {
		if ($pp->{warn_player}) {
			out dp => 0, "tell #$no " . $pp->{kickmsg};
		}
		if ($pp->{warn_irc}) {
			out irc => 0, "PRIVMSG $config{irc_channel} :\00304* kicking\017 " . $store{"playernick_byid_$id"} . "\017 for having a bad connection" .
				" (current ping/pl: \00304$ping/$pl\017)";
		}
		out dp => 0, "kick # $no bad connection";
		$pp->{"violation_$id"} = undef;
		return 0;
	}

	#do we have to warn the user?
	if ($warn && (scalar @{ $pp->{"violation_$id"} }) && ((scalar @{ $pp->{"violation_$id"} }) % $pp->{warnings}) == 0) {
		if ($pp->{warn_player}) {
			out dp => 0, "tell #$no " . $pp->{warnmsg};
		}
		if ($pp->{warn_irc}) {
			out irc => 0, "PRIVMSG $config{irc_channel} :\00308* warning\017 " . $store{"playernick_byid_$id"} . "\017 has a bad connection" .
				" (current ping/pl: \00304$ping/$pl\017)";
		}
	}
	return 0;
} ],

# For now will just empty our data at the end of a match
[ dp => q{^:end} => sub {
	my $pp = $store{plugin_ping-pl};
	foreach ( keys %{ $pp } ) {
		$pp->{$_} = undef if ($_ =~ m/^violation/);
	}
	return 0;
} ],
