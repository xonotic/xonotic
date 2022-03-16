%ca = (
	0 =>
	{
		name => "Xonotic official",
		check => sub
		{
			my ($inc) = @_;
			return 0 if ($inc >= 0) && check_dnsbl([qr/.*:.*:.*/], [], ['torexit.dan.me.uk', 'aspews.ext.sorbs.net']);
			return 0 if ($inc >= 0) && check_banlist('http://rm.sudo.rm-f.org/~xonotic/bans/?action=list&servers=*');
			#return 0 if check_sql('dbi:mysql:dbname=xonotic-ca', 'xonotic-ca', '************', 'ip', 0.2, 1, 20, 1000, $inc);
			return 0 if check_sql('dbi:Pg:dbname=xonotic-ca', '', '', 'ip', 0.2, 1, 20, 1000, $inc);
			1;
		}
	},
	1 =>
	{
		name => "Xonotic Hub",
		check => sub
		{
			my ($inc) = @_;
			return 0 if check_ipfiles('/home/xonotic-build/xonotic-release-build/misc/infrastructure/xhub/ips');
			1;
		}
	}
);
$default_ca = 0;
