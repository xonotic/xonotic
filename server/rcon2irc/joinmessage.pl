# Nexuiz rcon2irc plugin by Merlijn Hofstra licensed under GPL - joinmessage.pl
# Place this file inside the same directory as rcon2irc.pl and add the full filename to the plugins.

# Do not use more than 5 lines here, as they will be cut off by the client.
my @jmtext = (
	"Welcome to this Nexuiz server",
	"Have fun but please behave.",
);

$store{plugin_joinmessage} = \@jmtext;

sub out($$@);

[ dp => q{:join:(\d+):(\d+):([^:]*):(.*)} => sub {
	my ($id, $slot, $ip, $nick) = @_;
	my $text = $store{plugin_joinmessage};

	return 0 if ( $ip =~ m/^bot$/i );
	return 0 if defined $store{"playerid_byslot_$slot"};

	foreach ( @{ $text } ) {
		out dp => 0, "tell #$slot " . $_;
	}
	return 0;
} ],

[ dp => q{:part:(\d+)} => sub {
	my ($id) = @_;
	my $slot = $store{"playerslot_byid_$id"};

	$store{"playerid_byslot_$slot"} = undef;
	return 0;
} ],
