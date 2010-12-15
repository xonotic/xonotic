%ca = (
	0 =>
	{
		name => "Xonotic official",
		check => sub
		{
			my ($inc) = @_;
			return 0 if ($inc >= 0) && check_dnsbl([qr/.*:.*:.*/], [], ['torexit.dan.me.uk', 'aspews.ext.sorbs.net']);
			return 0 if ($inc >= 0) && check_banlist('http://rm.endoftheinternet.org/~xonotic/bans/?action=list&servers=*');
			return 0 if check_sql('dbi:mysql:dbname=xonotic_ca', 'xonotic_ca', '************', 'ip', $inc);
			1;
		}
	},
	15 =>
	{
		name => "Xonotic testing",
		check => sub { 1; }
	}
);
$default_ca = 15;
