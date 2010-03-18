sub out($$@);

# chat: Nexuiz server -> IRC channel, fastest record in race and ctf
[ dp => q{:recordset:(\d+):(.*)} => sub {
	my ($id, $record) = @_;
	my $nick = $store{"playernick_byid_$id"};
	
	my $time;
	if ($record < 60) {
		$time = $record;
	} else {
		my $minutes = int($record/60);
		my $seconds = $record - $minutes*60;
		$time = "$minutes:$seconds";
	}
	
	if ($store{map} =~ m/^ctf_/) {
		out irc => 0, "PRIVMSG $config{irc_channel} :* \00306record\017 $nick\017 set the fastest flag capture record with \00304$time\017 on \00304" . $store{map} . "\017";
	} else {
		out irc => 0, "PRIVMSG $config{irc_channel} :* \00306record\017 $nick\017 set the fastest lap record with \00304$time\017 on \00304" . $store{map} . "\017";
	}
	
	return 0;
} ],
