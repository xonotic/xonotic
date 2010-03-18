# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - bans.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

$store{plugin_bans}->{interval} = 60; #interval to displays bans

sub out ($$@);
sub schedule($$);

if (defined %config) {
	schedule sub {
		my ($timer) = @_;
		if ($store{plugin_bans}->{attempts}) {
			foreach (sort keys %{ $store{plugin_bans}->{attempts} }) {
				# Generate names
				my %temp = undef;
				my @names = grep !$temp{$_}++, @{ $store{plugin_bans}->{names}->{$_} };
			
				out irc => 0, "PRIVMSG $config{irc_channel} :\00305* banned client\017 \00304$_\017 was denied access \00304" .
					$store{plugin_bans}->{attempts}->{$_} . "\017 times" . 
					(scalar(@names) ? ' with name(s): ' . join("\017, ", @names) : '');
			}
			$store{plugin_bans}->{attempts} = undef;
			$store{plugin_bans}->{names} = undef;
		}
		schedule $timer => $store{plugin_bans}->{interval};;
	} => 1;
}


# old style without names
[ dp => q{(?:\^\d)?NOTE:(?:\^\d)? banned client (\d+\.\d+\.\d+\.\d+) just tried to enter} => sub {
	my ($ip) = @_;
	$store{plugin_bans}->{attempts}->{$ip} += 1;
	return 0;
} ],

# new style with names if known
[ dp => q{(?:\^\d)?NOTE:(?:\^\d)? banned client (\d+\.\d+\.\d+\.\d+) \((.*)\) just tried to enter} => sub {
	my ($ip,$name) = @_;
	$name = color_dp2irc $name;
	$store{plugin_bans}->{attempts}->{$ip} += 1;
	if ($name && $name ne 'unconnected') {
		push @{ $store{plugin_bans}->{names}->{$ip} }, $name;
	}
	return 0;
} ],

[ dp => q{(?:\^\d)?NOTE:(?:\^\d)? banned client (.*) has to go} => sub {
	my ($name) = @_;
	$name = color_dp2irc $name;
	out irc => 0, "PRIVMSG $config{irc_channel} :\00305* banned client\017 $name\017 was removed from the server";
	return 0;
} ],
