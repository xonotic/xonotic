# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - suggestmap.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

sub out($$@);

#read the suggest vote
[ dp => q{:vote:suggested:(.+):(\d+)} => sub {
	my ($map, $id) = @_;
	my $nick = $store{"playernick_byid_$id"} || 'console';
	out irc => 0, "PRIVMSG $config{irc_channel} :* map suggested: \00304$map\017 by $nick\017";
	return 0;
} ],
