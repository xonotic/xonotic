sub out($$@);
	# chat: IRC channel -> Nexuiz server, nick change
 	[ irc => q{:([^! ]*)![^ ]* (?i:NICK) :(.*)} => sub {
 		my ($nick, $newnick) = @_;
 		$nick = color_dpfix $nick;
 			# allow the nickname to contain colors in DP format! Therefore, NO color_irc2dp on the nickname!
 		$newnick = color_irc2dp $newnick;
 		$newnick =~ s/(["\\])/\\$1/g;
 		out dp => 0, "rcon2irc_say_as \"* $nick on IRC\" \"is now known as $newnick\"";
 		return 0;
 	} ],
