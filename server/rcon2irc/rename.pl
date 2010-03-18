# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - rename.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

sub out($$@);

[ irc => q{:(([^! ]*)![^ ]*) (?i:PRIVMSG) [^&#%]\S* :(.*)} => sub {
	my ($hostmask, $nick, $command) = @_;
	
	return 0 if (($store{logins}{$hostmask} || 0) < time());
	
	if ($command =~ m/^name (\d+) (.*)/i) {
		out dp => 0, "prvm_edictset server $1 netname \"$2\"";
		
		return -1;
	}
	
	return 0;
} ],
