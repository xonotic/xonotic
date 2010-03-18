#!/usr/bin/perl

# no warranty for this script
# and no documentation
# take it or leave it

use strict;
use warnings;
use FindBin; use lib $FindBin::Bin;
use IO::Socket;
use Socket;
use sigtrap qw(die normal-signals);
use WeaponEncounterProfile;

my ($statsfile) = @ARGV;
my $password = $ENV{rcon_password};
my $server = $ENV{rcon_address};
my $bind = $ENV{rcon_bindaddress};

my $stats;

sub AddKill($$$$$)
{
	my ($addr, $map, $attackerweapon, $targweapon, $type) = @_;
	$stats->event($addr, $map, $attackerweapon, $targweapon, $type);
}

sub StoreData()
{
	$stats->save();
}

sub LoadData()
{
	$stats = WeaponEncounterProfile->new($statsfile);
}

$SIG{ALRM} = sub
{
	print STDERR "Operation timed out.\n";
	exit 1;
};

our @discosockets = ();
sub LogDestUDP($)
{
	# connects to a DP server using rcon with log_dest_udp
	my ($sock) = @_;
	my $value = sprintf "%s:%d", $sock->sockhost(), $sock->sockport();
	$sock->send("\377\377\377\377rcon $password log_dest_udp", 0)
		or die "send rcon: $!";
	alarm 15;
	for(;;)
	{
		$sock->recv(my $response, 2048, 0)
			or die "recv: $!";
		if($response =~ /^\377\377\377\377n"log_dest_udp" is "(.*)" \[".*"\]\n$/s)
		{
			alarm 0;
			my @dests = split /\s+/, $1;
			return
				if grep { $_ eq $value } @dests;
			push @dests, $value;
			$sock->send("\377\377\377\377rcon $password log_dest_udp \"@dests\"");
			last;
		}
	}
	alarm 0;
	push @discosockets, [$sock, $value];

	END
	{
		for(@discosockets)
		{
			my ($s, $v) = @$_;
			# disconnects (makes the server stop send the data to us)
			$s->send("\377\377\377\377rcon $password log_dest_udp", 0)
				or die "send rcon: $!";
			alarm 15;
			for(;;)
			{
				$s->recv(my $response, 2048, 0)
					or die "recv: $!";
				if($response =~ /^\377\377\377\377n"log_dest_udp" is "(.*)" \[".*"\]\n$/s)
				{
					alarm 0;
					my @dests = split /\s+/, $1;
					return
						if not grep { $_ eq $v } @dests;
					@dests = grep { $_ ne $v } @dests;
					$s->send("\377\377\377\377rcon $password log_dest_udp \"@dests\"");
					last;
				}
			}
			alarm 0;
		}
	}
}

sub sockaddr_readable($)
{
	my ($binary) = @_;
	my ($port, $addr) = sockaddr_in $binary;
	return sprintf "%s:%d", inet_ntoa($addr), $port;
}

my $sock;
if(defined $bind)
{
	# bind to a port and wait for any packets
	$sock = IO::Socket::INET->new(Proto => 'udp', LocalAddr => $bind, LocalPort => 26000)
		or die "socket: $!";
}
else
{
	# connect to a DP server
	$sock = IO::Socket::INET->new(Proto => 'udp', PeerAddr => $server, PeerPort => 26000)
		or die "socket: $!";
	LogDestUDP $sock;
}
my %currentmap = ();

my %bots = ();

LoadData();
while(my $addr = sockaddr_readable $sock->recv($_, 2048, 0))
{
	$addr = $server
		if not defined $bind;
	s/^\377\377\377\377n//
		or next;
	for(split /\r?\n/, $_)
	{
		if(/^:gamestart:([^:]+):/)
		{
			StoreData();
			$currentmap{$addr} = $1;
			$bots{$addr} = {};
			print "($addr) switching to $1\n";
			next;
		}

		next
			unless defined $currentmap{$addr};
		if(/^:join:(\d+):bot:/)
		{
			$bots{$addr}{$1} = 1;
		}
		elsif(/^:kill:frag:(\d+):(\d+):type=(\d+):items=(\d+)([A-Z]*)(?:|(\d+)):victimitems=(\d+)([A-Z]*)(?:|(\d+))$/)
		{
			my ($a, $b, $type, $killweapon, $killflags, $killrunes, $victimweapon, $victimflags, $victimrules) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
			next
				if exists $bots{$addr}{$a} or exists $bots{$addr}{$b}; # only count REAL kills
			$type &= 0xFF
				if $type < 10000;
			$killweapon = $type
				if $stats->weaponid_valid($type); # if $type is not a weapon deathtype, count the weapon of the killer
			$killweapon = 0
				if not $stats->weaponid_valid($killweapon); # invalid weapon? that's 0 then
			$victimweapon = 0
				if not $stats->weaponid_valid($victimweapon); # dito
			next
				if $killflags =~ /S|I/ or $victimflags =~ /T/; # no strength, shield or typekills (these skew the statistics)
			AddKill($addr, $currentmap{$addr}, $killweapon, $victimweapon, +1);
		}
		elsif(/^:kill:suicide:\d+:\d+:type=(\d+):items=(\d+)([A-Z]*)(?:|(\d+))$/)
		{
			my ($type, $killweapon, $killflags, $killrunes) = ($1, $2, $3, $4, $5, $6, $7);
			$type &= 0xFF
				if $type < 10000;
			$killweapon = $type
				if $stats->weaponid_valid($type);
			$killweapon = 0
				if not $stats->weaponid_valid($killweapon);
			next
				if $killflags =~ /S/; # no strength suicides (happen too easily accidentally)
			AddKill($addr, $currentmap{$addr}, $killweapon, $killweapon, +1);
		}
	}
}
