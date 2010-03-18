# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - echo-rcon.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

sub out($$@);

[ dp => q{server received rcon command from (.*):  (.*)} => sub {
	my ($origin, $cmd) = @_;
	my @dests = split ' ', $store{plugin_echo-rcon}->{dest};
	return 0 if grep { $_ eq $origin } @dests; #do not relay rcon2irc commands
	my $origin = color_dp2irc $origin;
	out irc => 0, "PRIVMSG $config{irc_channel} :\00302* admin\017 command recieved from $origin: \00304$cmd\017";
	return 0;
} ],

[ dp => q{"log_dest_udp" is "([^"]*)" \["[^"]*"\]} => sub {
	my ($dest) = @_;
	$store{plugin_echo-rcon}->{dest} = $dest;
	return 0;
} ],
