# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - raw.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

# Use this plugin with extreme caution, it allows irc-admins to modify ANYTHING on your server.

# Usage: In query with the bot the raw command directs commands to the server or irc connection.
# Example: raw dp exec server.cfg
# Example: raw irc PRIVMSG #nexuiz: YaY!

sub out($$@);

[ irc => q{:(([^! ]*)![^ ]*) (?i:PRIVMSG) [^&#%]\S* :(.*)} => sub {
	my ($hostmask, $nick, $command) = @_;
	
	return 0 if (($store{logins}{$hostmask} || 0) < time());
	
	if ($command =~ m/^raw (dp|irc) (.+)/i) {
		out irc => 0, $2 if ($1 eq 'irc');
		out dp => 0, $2 if ($1 eq 'dp');
		
		out irc => 0, "PRIVMSG $nick :command executed";
		return -1;
	}
	
	return 0;
} ],
