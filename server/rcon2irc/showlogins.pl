# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - showlogins.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

{ my %sl = (
	show_success => 1, # only for logins to the irc bot
	show_failed => 1, # only for logins to the irc bot
	show_rcon_failure => 1,
	failed_interval => 60,
); $store{plugin_showlogins} = \%sl; }

sub out($$@);
sub schedule($$);

if (defined %config) {
	schedule sub {
		my ($timer) = @_;
		if ($store{plugin_showlogins}->{failed_attempts}) {
			# Generate hostmakes
			my %temp = undef;
			my @hostmasks = grep !$temp{$_}++, @{ $store{plugin_showlogins}->{failed_attempts} };
			
			foreach my $mask (@hostmasks) {
				my $count = 0;
				foreach (@{ $store{plugin_showlogins}->{failed_attempts} }) {
					$count++ if ($_ eq $mask);
				}
				
				out irc => 0, "PRIVMSG $config{irc_channel} :\00305* login failed\017 \00304$mask\017 tried to become an IRC admin \00304$count\017 times";
			}
			
			$store{plugin_showlogins}->{failed_attempts} = undef;
		}
		
		if ($store{plugin_showlogins}->{rcon_fail}) {
			my %temp = undef;
			my @names = grep !$temp{$_}++, @{ $store{plugin_showlogins}->{rcon_fail} };
			
			foreach my $name (@names) {
				my $count = 0;
				foreach (@{ $store{plugin_showlogins}->{rcon_fail} }) {
					$count++ if ($_ eq $name);
				}
				
				out irc => 0, "PRIVMSG $config{irc_channel} :\00305* login failed\017 \00304$name\017 tried to use rcon commands \00304$count\017 times";
			}
			
			$store{plugin_showlogins}->{rcon_fail} = undef;
		}
		
		schedule $timer => $store{plugin_showlogins}->{failed_interval};;
	} => 1;
}

[ irc => q{:(([^! ]*)![^ ]*) (?i:PRIVMSG) [^&#%]\S* :(.*)} => sub {
	my ($hostmask, $nick, $command) = @_;
	my $sl = $store{plugin_showlogins};
	
	if ($command eq "login $config{irc_admin_password}") {
		out irc => 0, "PRIVMSG $config{irc_channel} :\00310* login\017 $nick is now logged in as an IRC admin" if ($sl->{show_success});
		return 0;
	}
	
	if ($command =~ m/^login/i && $sl->{show_failed}) {
		push @{ $store{plugin_showlogins}->{failed_attempts} }, $hostmask;
	}
	
	return 0;
} ],

# failed rcon attempts
[ dp => q{server denied rcon access to (.*)} => sub {
	my ($name) = map { color_dp2irc $_ } @_;
	my $sl = $store{plugin_showlogins};
	
	if ($sl->{show_rcon_failure}) {
		push @{ $store{plugin_showlogins}->{rcon_fail} }, $name
	}
	
	return 0;
} ],
