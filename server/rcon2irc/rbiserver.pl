sub out($$@);

sub markmap($$$$;$)
{
	my ($state, $map, $pro, $total, $who) = @_;
	open my $fh, '>>', "$ENV{HOME}/.nexuiz/__votelog.$config{irc_nick}.txt"
		or die "votelog open: $!";
	print $fh "@{[time()]} $config{irc_nick} $state $map $pro $total" . (defined $who ? " $who" : "") . "\n";
	close $fh;
}

# the AOL calendar
[ dp => q{\001(.*?)\^7: d} => sub {
	my $aoltime = time() - 746748000;
	my $day = int($aoltime / 86400);
	my $wday = [qw[Tue Wed Thu Fri Sat Sun Mon]]->[$day % 7];
	my $hour = int($aoltime / 3600) % 24;
	my $minute = int($aoltime / 60) % 60;
	my $second = int($aoltime / 1) % 60;
	out dp => 0, sprintf 'rcon2irc_say_as "AOL service" "The time is %3s Sep %2d %02d:%02d:%02d 1993"',
		$wday, $day, $hour, $minute, $second;
	return 1;
} ],

# map vote logging
[ dp => q{:vote:suggestion_accepted:(.*)} => sub {
	my ($map) = @_;
	markmap suggestion_accepted => $map, $store{rbi_winvotes}, $store{rbi_totalvotes};
	return 0;
} ],
[ dp => q{:vote:suggested:(.*?):\d+:(.*)} => sub {
	my ($map, $who) = @_;
	markmap suggested => $map, 1, 1, $who;
	return 0;
} ],
[ dp => q{\001\^2\* .*'s vote for \^1gotomap (.*)\^2 was accepted} => sub {
	my ($map) = @_;
	markmap voted => $map, 1, 1;
	return 0;
} ],
[ dp => q{\001\^2\* .*'s vote for \^1timelimit -1\^2 was accepted} => sub {
	markmap cancelled => $store{map}, 1, 1;
	return 0;
} ],
[ dp => q{:vote:(keeptwo|finished):(.*)} => sub {
	my ($status, $result) = @_;
	my @result = split /:/, $result;
	my $totalvotes = 0;
	my $cutoff = -1;
	my @allmaps = map
	{
		$cutoff = $_ if $result[2*$_] eq '';
		$totalvotes += int($result[2*$_+1] || 0);
		[$result[2*$_], int($result[2*$_+1] || 0)]
	} 0..((@result-1)/2);
	die "Invalid vote result: $result" unless $cutoff >= 0;
	my @winners = @allmaps[0..($cutoff-1)];
	my @losers = @allmaps[($cutoff+1)..(@allmaps-1)];
	my $winvotes = 0;
	$winvotes += $_->[1] for @winners;
	if($status eq 'keeptwo')
	{
		markmap irrelevant_relative => $_->[0], $winvotes, $totalvotes
			for @losers;
	}
	elsif($status eq 'finished')
	{
		markmap((@losers == 1 ? 'duel_winner' : 'winner_absolute') => $_->[0], $_->[1], $totalvotes)
			for @winners;
		markmap((@losers == 1 ? 'duel_loser' : 'irrelevant_absolute') => $_->[0], $winvotes, $totalvotes)
			for @losers;
	}
	$store{rbi_winvotes} = $winvotes;
	$store{rbi_totalvotes} = $totalvotes;
	return 0;
} ],
[ dp => q{pure: -(\S+) (.*)} => sub {
	my ($status, $nick) = @_;
	$nick = color_dp2irc $nick;
	out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION thinks $nick is $status\001"
		unless $status eq 'MODIFIED'; # in this case, either DETAIL_TIMEOUT or DETAIL_MISMATCH follows
	return 0;
} ],
[ dp => q{pure: \*DETAIL_MISMATCH (.*) (\S+)$} => sub {
	my ($nick, $file) = @_;
	$nick = color_dp2irc $nick;
	out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION thinks $nick has a modified $file\001";
	return 0;
} ],
[ dp => q{pure: \*DETAIL_TIMEOUT (.*)} => sub {
	my ($nick) = @_;
	$nick = color_dp2irc $nick;
	out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION thinks $nick refuses to tell us which file is modified\001";
	return 0;
} ],
[ dp => q{pure: \*DETAIL_CVAR (.*) (\S+) (.*)$} => sub {
	my ($nick, $cvar, $value) = @_;
	$nick = color_dp2irc $nick;
	out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION thinks $nick has changed $cvar to $value\001";
	return 0;
} ],
[ dp => q{:recordset:(\d+):.*} => sub {
	my ($id) = @_;
	my $ip = $store{"playerip_byid_$id"};
	my $slot = $store{"playerslot_byid_$id"};
	my $name = $config{irc_nick};
	$name =~ s/Nex//; # haggerNexCTF -> haggerCTF
	$name =~ s/^rm/hagger/g; # rmRace -> haggerRace
	my $map = $store{map};
	$map =~ s/^[a-z]*_//;
	$ip =~ s/\./-/g;
	my $pattern = "/home/nexuiz/home-$name/data/sv_autodemos/????-??-??_??-??_${map}_${slot}_${ip}-*.dem";
	if(my @result = glob $pattern)
	{
		for(@result)
		{
			my @l = stat $_;
			next if $l[9] < time() - 60; # too old
			print "Cleaning up demos: protecting $_\n";
			chmod 0444, $_;
			open my $fh, ">", "$_.nick";
			printf $fh "%s\n", color_dp2none($store{"playernickraw_byid_$id"});
			close $fh;
			chmod 0444, "$_.nick";
		}
	}
	else
	{
		print "Record set but could not find the demo using $pattern\n";
	}
	return 0;
} ],
# delete demos at the end of the match
[ dp => q{:end} => sub {
	my $name = $config{irc_nick};
	$name =~ s/Nex//; # haggerNexCTF -> haggerCTF
	my $pattern = "/home/nexuiz/data/home-$name/data/sv_autodemos/*.dem";
	print "Checking $pattern...\n";
	for(glob $pattern)
	{
		next if not -w $_;   # protected demo (by record, or other markers)
		my @l = stat $_;
		next if $l[9] >= time() - 60; # too new
		print "Cleaning up demos: deleting $_\n";
		unlink $_;
	}
	return 0;
} ],
