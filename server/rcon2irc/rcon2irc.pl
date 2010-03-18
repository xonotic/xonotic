#!/usr/bin/perl

our $VERSION = '0.4.2 svn $Revision$';

# Copyright (c) 2008 Rudolf "divVerent" Polzer
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# MISC STRING UTILITY ROUTINES to convert between DarkPlaces and IRC conventions

# convert mIRC color codes to DP color codes
our @color_irc2dp_table = (7, 0, 4, 2, 1, 1, 6, 1, 3, 2, 5, 5, 4, 6, 7, 7);
our @color_dp2irc_table = (-1, 4, 9, 8, 12, 11, 13, -1, -1, -1); # not accurate, but legible
our @color_dp2ansi_table = ("m", "1;31m", "1;32m", "1;33m", "1;34m", "1;36m", "1;35m", "m", "1m", "1m"); # not accurate, but legible
our %color_team2dp_table = (5 => 1, 14 => 4, 13 => 3, 10 => 6);
our %color_team2irc_table = (5 => 4, 14 => 12, 13 => 8, 10 => 13);
sub color_irc2dp($)
{
	my ($message) = @_;
	$message =~ s/\^/^^/g;
	my $color = 7;
	$message =~ s{\003(\d\d?)(?:,(\d?\d?))?|(\017)}{
		# $1 is FG, $2 is BG, but let's ignore BG
		my $oldcolor = $color;
		if($3)
		{
			$color = 7;
		}
		else
		{
			$color = $color_irc2dp_table[$1];
			$color = $oldcolor if not defined $color;
		}
		($color == $oldcolor) ? '' : '^' . $color;
	}esg;
	$message =~ s{[\000-\037]}{}gs; # kill bold etc. for now
	return $message;
}

our @text_qfont_table = ( # ripped from DP console.c qfont_table
    "\0", '#',  '#',  '#',  '#',  '.',  '#',  '#',
    '#',  9,    10,   '#',  ' ',  13,   '.',  '.',
    '[',  ']',  '0',  '1',  '2',  '3',  '4',  '5',
    '6',  '7',  '8',  '9',  '.',  '<',  '=',  '>',
    ' ',  '!',  '"',  '#',  '$',  '%',  '&',  '\'',
    '(',  ')',  '*',  '+',  ',',  '-',  '.',  '/',
    '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',
    '8',  '9',  ':',  ';',  '<',  '=',  '>',  '?',
    '@',  'A',  'B',  'C',  'D',  'E',  'F',  'G',
    'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',
    'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',
    'X',  'Y',  'Z',  '[',  '\\', ']',  '^',  '_',
    '`',  'a',  'b',  'c',  'd',  'e',  'f',  'g',
    'h',  'i',  'j',  'k',  'l',  'm',  'n',  'o',
    'p',  'q',  'r',  's',  't',  'u',  'v',  'w',
    'x',  'y',  'z',  '{',  '|',  '}',  '~',  '<',
    '<',  '=',  '>',  '#',  '#',  '.',  '#',  '#',
    '#',  '#',  ' ',  '#',  ' ',  '>',  '.',  '.',
    '[',  ']',  '0',  '1',  '2',  '3',  '4',  '5',
    '6',  '7',  '8',  '9',  '.',  '<',  '=',  '>',
    ' ',  '!',  '"',  '#',  '$',  '%',  '&',  '\'',
    '(',  ')',  '*',  '+',  ',',  '-',  '.',  '/',
    '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',
    '8',  '9',  ':',  ';',  '<',  '=',  '>',  '?',
    '@',  'A',  'B',  'C',  'D',  'E',  'F',  'G',
    'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',
    'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',
    'X',  'Y',  'Z',  '[',  '\\', ']',  '^',  '_',
    '`',  'a',  'b',  'c',  'd',  'e',  'f',  'g',
    'h',  'i',  'j',  'k',  'l',  'm',  'n',  'o',
    'p',  'q',  'r',  's',  't',  'u',  'v',  'w',
    'x',  'y',  'z',  '{',  '|',  '}',  '~',  '<'
);
sub text_dp2ascii($)
{
	my ($message) = @_;
	$message = join '', map { $text_qfont_table[ord $_] } split //, $message;
}

sub color_dp_transform(&$)
{
	my ($block, $message) = @_;

	$message =~ s{(?:(\^\^)|\^x([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])|\^([0-9])|(.))(?=([0-9,]?))}{
		defined $1 ? $block->(char => '^', $7) :
		defined $2 ? $block->(rgb => [hex $2, hex $3, hex $4], $7) :
		defined $5 ? $block->(color => $5, $7) :
		defined $6 ? $block->(char => $6, $7) :
			die "Invalid match";
	}esg;

	return $message;
}

sub color_dp2none($)
{
	my ($message) = @_;

	return color_dp_transform
	{
		my ($type, $data, $next) = @_;
		$type eq 'char'
			? $text_qfont_table[ord $data]
			: "";
	}
	$message;
}

sub color_rgb2basic($)
{
	my ($data) = @_;
	my ($R, $G, $B) = @$data;
	my $min = [sort { $a <=> $b } ($R, $G, $B)]->[0];
	my $max = [sort { $a <=> $b } ($R, $G, $B)]->[-1];

	my $v = $max / 15;
	my $s = ($max == $min) ? 0 : 1 - $min/$max;

	if($s < 0.2)
	{
		return 0 if $v < 0.5;
		return 7;
	}

	my $h;
	if($max == $min)
	{
		$h = 0;
	}
	elsif($max == $R)
	{
		$h = (60 * ($G - $B) / ($max - $min)) % 360;
	}
	elsif($max == $G)
	{
		$h = (60 * ($B - $R) / ($max - $min)) + 120;
	}
	elsif($max == $B)
	{
		$h = (60 * ($R - $G) / ($max - $min)) + 240;
	}

	return 1 if $h < 36;
	return 3 if $h < 80;
	return 2 if $h < 150;
	return 5 if $h < 200;
	return 4 if $h < 270;
	return 6 if $h < 330;
	return 1;
}

sub color_dp_rgb2basic($)
{
	my ($message) = @_;
	return color_dp_transform
	{
		my ($type, $data, $next) = @_;
		$type eq 'char'  ? ($data eq '^' ? '^^' : $data) :
		$type eq 'color' ? "^$data" :
		$type eq 'rgb'   ? "^" . color_rgb2basic $data :
			die "Invalid type";
	}
	$message;
}

sub color_dp2irc($)
{
	my ($message) = @_;
	my $color = -1;
	return color_dp_transform
	{
		my ($type, $data, $next) = @_;

		if($type eq 'rgb')
		{
			$type = 'color';
			$data = color_rgb2basic $data;
		}

		$type eq 'char'  ? $text_qfont_table[ord $data] :
		$type eq 'color' ? do {
			my $oldcolor = $color;
			$color = $color_dp2irc_table[$data];

			$color == $oldcolor               ? '' :
			$color < 0                        ? "\017" :
			(index '0123456789,', $next) >= 0 ? "\003$color\002\002" :
			                                    "\003$color";
		} :
			die "Invalid type";
	}
	$message;
}

sub color_dp2ansi($)
{
	my ($message) = @_;
	my $color = -1;
	return color_dp_transform
	{
		my ($type, $data, $next) = @_;

		if($type eq 'rgb')
		{
			$type = 'color';
			$data = color_rgb2basic $data;
		}

		$type eq 'char'  ? $text_qfont_table[ord $data] :
		$type eq 'color' ? do {
			my $oldcolor = $color;
			$color = $color_dp2ansi_table[$data];

			$color eq $oldcolor ? '' :
			                      "\033[${color}"
		} :
			die "Invalid type";
	}
	$message;
}

sub color_dpfix($)
{
	my ($message) = @_;
	# if the message ends with an odd number of ^, kill one
	chop $message if $message =~ /(?:^|[^\^])\^(\^\^)*$/;
	return $message;
}




# Interfaces:
#   Connection:
#     $conn->sockname() returns a connection type specific representation
#       string of the local address, or undef if not applicable.
#     $conn->send("string") sends something over the connection.
#     $conn->recv() receives a string from the connection, or returns "" if no
#       data is available.
#     $conn->fds() returns all file descriptors used by the connection, so one
#       can use select() on them.
#   Channel:
#     Usually wraps around a connection and implements a command based
#     structure over it. It usually is constructed using new
#     ChannelType($connection, someparameters...)
#     @cmds = $chan->join_commands(@cmds) joins multiple commands to a single
#       command string if the protocol supports it, or does nothing and leaves
#       @cmds unchanged if the protocol does not support that usage (this is
#       meant to save send() invocations).
#     $chan->send($command, $nothrottle) sends a command over the channel. If
#       $nothrottle is sent, the command must not be left out even if the channel
#       is saturated (for example, because of IRC's flood control mechanism).
#     $chan->quote($str) returns a string in a quoted form so it can safely be
#       inserted as a substring into a command, or returns $str as is if not
#       applicable. It is assumed that the result of the quote method is used
#       as part of a quoted string, if the protocol supports that.
#     $chan->recv() returns a list of received commands from the channel, or
#       the empty list if none are available.
#     $conn->fds() returns all file descriptors used by the channel's
#       connections, so one can use select() on them.







# Socket connection.
# Represents a connection over a socket.
# Mainly used to wrap a channel around it for, in this case, line based or rcon-like operation.
package Connection::Socket;
use strict;
use warnings;
use IO::Socket::INET;
use IO::Handle;

# Constructor:
#   my $conn = new Connection::Socket(tcp => "localaddress" => "remoteaddress" => 6667);
# If the remote address does not contain a port number, the numeric port is
# used (it serves as a default port).
sub new($$)
{
	my ($class, $proto, $local, $remote, $defaultport) = @_;
	my $sock = IO::Socket::INET->new(
		Proto => $proto,
		(length($local) ? (LocalAddr => $local) : ()),
		PeerAddr => $remote,
		PeerPort => $defaultport
	) or die "socket $proto/$local/$remote/$defaultport: $!";
	$sock->blocking(0);
	my $you = {
		# Mortal fool! Release me from this wretched tomb! I must be set free
		# or I will haunt you forever! I will hide your keys beneath the
		# cushions of your upholstered furniture... and NEVERMORE will you be
		# able to find socks that match!
		sock => $sock,
		# My demonic powers have made me OMNIPOTENT! Bwahahahahahahaha!
	};
	return
		bless $you, 'Connection::Socket';
}

# $sock->sockname() returns the local address of the socket.
sub sockname($)
{
	my ($self) = @_;
	my ($port, $addr) = sockaddr_in $self->{sock}->sockname();
	return "@{[inet_ntoa $addr]}:$port";
}

# $sock->send($data) sends some data over the socket; on success, 1 is returned.
sub send($$)
{
	my ($self, $data) = @_;
	return 1
		if not length $data;
	if(not eval { $self->{sock}->send($data); })
	{
		warn "$@";
		return 0;
	}
	return 1;
}

# $sock->recv() receives as much as possible from the socket (or at most 32k). Returns "" if no data is available.
sub recv($)
{
	my ($self) = @_;
	my $data = "";
	if(defined $self->{sock}->recv($data, 32768, 0))
	{
		return $data;
	}
	elsif($!{EAGAIN})
	{
		return "";
	}
	else
	{
		return undef;
	}
}

# $sock->fds() returns the socket file descriptor.
sub fds($)
{
	my ($self) = @_;
	return fileno $self->{sock};
}







# Line-based buffered connectionless FIFO channel.
# Whatever is sent to it using send() is echoed back when using recv().
package Channel::FIFO;
use strict;
use warnings;

# Constructor:
#   my $chan = new Channel::FIFO();
sub new($)
{
	my ($class) = @_;
	my $you = {
		buffer => []
	};
	return
		bless $you, 'Channel::FIFO';
}

sub join_commands($@)
{
	my ($self, @data) = @_;
	return @data;
}

sub send($$$)
{
	my ($self, $line, $nothrottle) = @_;
	push @{$self->{buffer}}, $line;
}

sub quote($$)
{
	my ($self, $data) = @_;
	return $data;
}

sub recv($)
{
	my ($self) = @_;
	my $r = $self->{buffer};
	$self->{buffer} = [];
	return @$r;
}

sub fds($)
{
	my ($self) = @_;
	return ();
}







# QW rcon protocol channel.
# Wraps around a UDP based Connection and sends commands as rcon commands as
# well as receives rcon replies. The quote and join_commands methods are using
# DarkPlaces engine specific rcon protocol extensions.
package Channel::QW;
use strict;
use warnings;
use Digest::HMAC;
use Digest::MD4;

# Constructor:
#   my $chan = new Channel::QW($connection, "password");
sub new($$$)
{
	my ($class, $conn, $password, $secure, $timeout) = @_;
	my $you = {
		connector => $conn,
		password => $password,
		recvbuf => "",
		secure => $secure,
		timeout => $timeout,
	};
	return
		bless $you, 'Channel::QW';
}

# Note: multiple commands in one rcon packet is a DarkPlaces extension.
sub join_commands($@)
{
	my ($self, @data) = @_;
	return join "\0", @data;
}

sub send($$$)
{
	my ($self, $line, $nothrottle) = @_;
	if($self->{secure} > 1)
	{
		$self->{connector}->send("\377\377\377\377getchallenge");
		my $c = $self->recvchallenge();
		return 0 if not defined $c;
		my $key = Digest::HMAC::hmac("$c $line", $self->{password}, \&Digest::MD4::md4);
		return $self->{connector}->send("\377\377\377\377srcon HMAC-MD4 CHALLENGE $key $c $line");
	}
	elsif($self->{secure})
	{
		my $t = sprintf "%ld.%06d", time(), int rand 1000000;
		my $key = Digest::HMAC::hmac("$t $line", $self->{password}, \&Digest::MD4::md4);
		return $self->{connector}->send("\377\377\377\377srcon HMAC-MD4 TIME $key $t $line");
	}
	else
	{
		return $self->{connector}->send("\377\377\377\377rcon $self->{password} $line");
	}
}

# Note: backslash and quotation mark escaping is a DarkPlaces extension.
sub quote($$)
{
	my ($self, $data) = @_;
	$data =~ s/[\000-\037]//g;
	$data =~ s/([\\"])/\\$1/g;
	$data =~ s/\$/\$\$/g;
	return $data;
}

sub recvchallenge($)
{
	my ($self) = @_;

	my $sel = IO::Select->new($self->fds());
	my $endtime_max = Time::HiRes::time() + $self->{timeout};
	my $endtime = $endtime_max;

	while((my $dt = $endtime - Time::HiRes::time()) > 0)
	{
		if($sel->can_read($dt))
		{
			for(;;)
			{
				my $s = $self->{connector}->recv();
				die "read error\n"
					if not defined $s;
				length $s
					or last;
				if($s =~ /^\377\377\377\377challenge (.*)$/s)
				{
					return $1;
				}
				next
					if $s !~ /^\377\377\377\377n(.*)$/s;
				$self->{recvbuf} .= $1;
			}
		}
	}
	return undef;
}

sub recv($)
{
	my ($self) = @_;
	for(;;)
	{
		my $s = $self->{connector}->recv();
		die "read error\n"
			if not defined $s;
		length $s
			or last;
		next
			if $s !~ /^\377\377\377\377n(.*)$/s;
		$self->{recvbuf} .= $1;
	}
	my @out = ();
	while($self->{recvbuf} =~ s/^(.*?)(?:\r\n?|\n)//)
	{
		push @out, $1;
	}
	return @out;
}

sub fds($)
{
	my ($self) = @_;
	return $self->{connector}->fds();
}







# Line based protocol channel.
# Wraps around a TCP based Connection and sends commands as text lines
# (separated by CRLF). When reading responses from the Connection, any type of
# line ending is accepted.
# A flood control mechanism is implemented.
package Channel::Line;
use strict;
use warnings;
use Time::HiRes qw/time/;

# Constructor:
#   my $chan = new Channel::Line($connection);
sub new($$)
{
	my ($class, $conn) = @_;
	my $you = {
		connector => $conn,
		recvbuf => "",
		capacity => undef,
		linepersec => undef,
		maxlines => undef,
		lastsend => time()
	};
	return 
		bless $you, 'Channel::Line';
}

sub join_commands($@)
{
	my ($self, @data) = @_;
	return @data;
}

# Sets new flood control parameters:
#   $chan->throttle(maximum lines per second, maximum burst length allowed to
#     exceed the lines per second limit);
#   RFC 1459 describes these parameters to be 0.5 and 5 for the IRC protocol.
#   If the $nothrottle flag is set while sending, the line is sent anyway even
#   if flooding would take place.
sub throttle($$$)
{
	my ($self, $linepersec, $maxlines) = @_;
	$self->{linepersec} = $linepersec;
	$self->{maxlines} = $maxlines;
	$self->{capacity} = $maxlines;
}

sub send($$$)
{
	my ($self, $line, $nothrottle) = @_;
	my $t = time();
	if(defined $self->{capacity})
	{
		$self->{capacity} += ($t - $self->{lastsend}) * $self->{linepersec};
		$self->{lastsend} = $t;
		$self->{capacity} = $self->{maxlines}
			if $self->{capacity} > $self->{maxlines};
		if(!$nothrottle)
		{
			return -1
				if $self->{capacity} < 0;
		}
		$self->{capacity} -= 1;
	}
	$line =~ s/\r|\n//g;
	return $self->{connector}->send("$line\r\n");
}

sub quote($$)
{
	my ($self, $data) = @_;
	$data =~ s/\r\n?/\n/g;
	$data =~ s/\n/*/g;
	return $data;
}

sub recv($)
{
	my ($self) = @_;
	for(;;)
	{
		my $s = $self->{connector}->recv();
		die "read error\n"
			if not defined $s;
		length $s
			or last;
		$self->{recvbuf} .= $s;
	}
	my @out = ();
	while($self->{recvbuf} =~ s/^(.*?)(?:\r\n?|\n)//)
	{
		push @out, $1;
	}
	return @out;
}

sub fds($)
{
	my ($self) = @_;
	return $self->{connector}->fds();
}






# main program... a gateway between IRC and DarkPlaces servers
package main;

use strict;
use warnings;
use IO::Select;
use Digest::SHA;
use Digest::HMAC;
use Time::HiRes qw/time/;

our @handlers = (); # list of [channel, expression, sub to handle result]
our @tasks = (); # list of [time, sub]
our %channels = ();
our %store = (
	irc_nick => "",
	playernick_byid_0 => "(console)",
);
our %config = (
	irc_server => undef,
	irc_nick => undef,
	irc_nick_alternates => "",
	irc_user => undef,
	irc_channel => undef,
	irc_ping_delay => 120,
	irc_trigger => "",

	irc_nickserv_password => "",
	irc_nickserv_identify => 'PRIVMSG NickServ :IDENTIFY %2$s',
	irc_nickserv_ghost => 'PRIVMSG NickServ :GHOST %1$s %2$s',
	irc_nickserv_ghost_attempts => 3,

	irc_quakenet_authname => "",
	irc_quakenet_password => "",
	irc_quakenet_authusers => "",
	irc_quakenet_getchallenge => 'PRIVMSG Q@CServe.quakenet.org :CHALLENGE',
	irc_quakenet_challengeauth => 'PRIVMSG Q@CServe.quakenet.org :CHALLENGEAUTH',
	irc_quakenet_challengeprefix => ':Q!TheQBot@CServe.quakenet.org NOTICE [^:]+ :CHALLENGE',

	irc_announce_slotsfree => 1,
	irc_announce_mapchange => 'always',

	dp_server => undef,
	dp_secure => 1,
	dp_secure_challengetimeout => 1,
	dp_listen => "", 
	dp_password => undef,
	dp_status_delay => 30,
	dp_server_from_wan => "",
	irc_local => "",

	irc_admin_password => "",
	irc_admin_timeout => 3600,
	irc_admin_quote_re => "",

	irc_reconnect_delay => 300,

	plugins => "",
);



# Nexuiz specific parsing of some server messages

sub nex_slotsstring()
{
	my $slotsstr = "";
	if(defined $store{slots_max})
	{
		my $slots = $store{slots_max} - $store{slots_active};
		my $slots_s = ($slots == 1) ? '' : 's';
		$slotsstr = " ($slots free slot$slots_s)";
		my $s = $config{dp_server_from_wan} || $config{dp_server};
		$slotsstr .= "; join now: \002nexuiz +connect $s"
			if $slots >= 1 and not $store{lms_blocked};
	}
	return $slotsstr;
}



# Do we have a config file? If yes, read and parse it (syntax: key = value
# pairs, separated by newlines), if not, complain.
die "Usage: $0 configfile\n"
	unless @ARGV == 1;

open my $fh, "<", $ARGV[0]
	or die "open $ARGV[0]: $!";
while(<$fh>)
{
	chomp;
	/^#/ and next;
	/^(.*?)\s*=(?:\s*(.*))?$/ or next;
	warn "Undefined config item: $1"
		unless exists $config{$1};
	$config{$1} = defined $2 ? $2 : "";
}
close $fh;
my @missing = grep { !defined $config{$_} } keys %config;
die "The following config items are missing: @missing"
	if @missing;



# Create a channel for error messages and other internal status messages...

$channels{system} = new Channel::FIFO();

# for example, quit messages caused by signals (if SIGTERM or SIGINT is first
# received, try to shut down cleanly, and if such a signal is received a second
# time, just exit)
my $quitting = 0;
$SIG{INT} = sub {
	exit 1 if $quitting++;
	$channels{system}->send("quit SIGINT");
};
$SIG{TERM} = sub {
	exit 1 if $quitting++;
	$channels{system}->send("quit SIGTERM");
};



# Create the two channels to gateway between...

$channels{irc} = new Channel::Line(new Connection::Socket(tcp => $config{irc_local} => $config{irc_server} => 6667));
$channels{dp} = new Channel::QW(my $dpsock = new Connection::Socket(udp => $config{dp_listen} => $config{dp_server} => 26000), $config{dp_password}, $config{dp_secure}, $config{dp_secure_challengetimeout});
$config{dp_listen} = $dpsock->sockname();
print "Listening on $config{dp_listen}\n";

$channels{irc}->throttle(0.5, 5);


# Utility routine to write to a channel by name, also outputting what's been written and some status
sub out($$@)
{
	my $chanstr = shift;
	my $nothrottle = shift;
	my $chan = $channels{$chanstr};
	if(!$chan)
	{
		print "UNDEFINED: $chanstr, ignoring message\n";
		return;
	}
	@_ = $chan->join_commands(@_);
	for(@_)
	{
		my $result = $chan->send($_, $nothrottle);
		if($result > 0)
		{
			print "           $chanstr << $_\n";
		}
		elsif($result < 0)
		{
			print "FLOOD:     $chanstr << $_\n";
		}
		else
		{
			print "ERROR:     $chanstr << $_\n";
			$channels{system}->send("error $chanstr", 0);
		}
	}
}



# Schedule a task for later execution by the main loop; usage: schedule sub {
# task... }, $time; When a scheduled task is run, a reference to the task's own
# sub is passed as first argument; that way, the task is able to re-schedule
# itself so it gets periodically executed.
sub schedule($$)
{
	my ($sub, $time) = @_;
	push @tasks, [time() + $time, $sub];
}

# On IRC error, delete some data store variables of the connection, and
# reconnect to the IRC server soon (but only if someone is actually playing)
sub irc_error()
{
	# prevent multiple instances of this timer
	return if $store{irc_error_active};
	$store{irc_error_active} = 1;

	delete $channels{irc};
	schedule sub {
		my ($timer) = @_;
		if(!defined $store{slots_active})
		{
			# DP is not running, then delay IRC reconnecting
			#use Data::Dumper; print Dumper \$timer;
			schedule $timer => 1;
			return;
			# this will keep irc_error_active
		}
		$channels{irc} = new Channel::Line(new Connection::Socket(tcp => "" => $config{irc_server} => 6667));
		delete $store{$_} for grep { /^irc_/ } keys %store;
		$store{irc_nick} = "";
		schedule sub {
			my ($timer) = @_;
			out dp => 0, 'sv_cmd bans', 'status 1', 'log_dest_udp';
			$store{status_waiting} = -1;
		} => 1;
		# this will clear irc_error_active
	} => $config{irc_reconnect_delay};
	return 0;
}

sub uniq(@)
{
	my @out = ();
	my %found = ();
	for(@_)
	{
		next if $found{$_}++;
		push @out, $_;
	}
	return @out;
}

# IRC joining (if this is called as response to a nick name collision, $is433 is set);
# among other stuff, it performs NickServ or Quakenet authentication. This is to be called
# until the channel has been joined for every message that may be "interesting" (basically,
# IRC 001 hello messages, 443 nick collision messages and some notices by services).
sub irc_joinstage($)
{
	my($is433) = @_;

	return 0
		if $store{irc_joined_channel};
	
		#use Data::Dumper; print Dumper \%store;

	if($is433)
	{
		if(length $store{irc_nick})
		{
			# we already have another nick, but couldn't change to the new one
			# try ghosting and then get the nick again
			if(length $config{irc_nickserv_password})
			{
				if(++$store{irc_nickserv_ghost_attempts} <= $config{irc_nickserv_ghost_attempts})
				{
					$store{irc_nick_requested} = $config{irc_nick};
					out irc => 1, sprintf($config{irc_nickserv_ghost}, $config{irc_nick}, $config{irc_nickserv_password});
					schedule sub {
						out irc => 1, "NICK $config{irc_nick}";
					} => 1;
					return; # we'll get here again for the NICK success message, or for a 433 failure
				}
				# otherwise, we failed to ghost and will continue with the wrong
				# nick... also, no need to try to identify here
			}
			# otherwise, we can't handle this and will continue with our wrong nick
		}
		else
		{
			# we failed to get an initial nickname
			# change ours a bit and try again

			my @alternates = uniq ($config{irc_nick}, grep { $_ ne "" } split /\s+/, $config{irc_nick_alternates});
			my $nextnick = undef;
			for(0..@alternates-2)
			{
				if($store{irc_nick_requested} eq $alternates[$_])
				{
					$nextnick = $alternates[$_+1];
				}
			}
			if($store{irc_nick_requested} eq $alternates[@alternates-1]) # this will only happen once
			{
				$store{irc_nick_requested} = $alternates[0];
				# but don't set nextnick, so we edit it
			}
			if(defined $nextnick)
			{
				$store{irc_nick_requested} = $nextnick;
			}
			else
			{
				for(;;)
				{
					if(length $store{irc_nick_requested} < 9)
					{
						$store{irc_nick_requested} .= '_';
					}
					else
					{
						substr $store{irc_nick_requested}, int(rand length $store{irc_nick_requested}), 1, chr(97 + int rand 26);
					}
					last unless grep { $_ eq $store{irc_nick_requested} } @alternates;
				}
			}
			out irc => 1, "NICK $store{irc_nick_requested}";
			return; # when it fails, we'll get here again, and when it succeeds, we will continue
		}
	}

	# we got a 001 or a NICK message, so $store{irc_nick} has been updated
	if(length $config{irc_nickserv_password})
	{
		if($store{irc_nick} eq $config{irc_nick})
		{
			# identify
			out irc => 1, sprintf($config{irc_nickserv_identify}, $config{irc_nick}, $config{irc_nickserv_password});
		}
		else
		{
			# ghost
			if(++$store{irc_nickserv_ghost_attempts} <= $config{irc_nickserv_ghost_attempts})
			{
				$store{irc_nick_requested} = $config{irc_nick};
				out irc => 1, sprintf($config{irc_nickserv_ghost}, $config{irc_nick}, $config{irc_nickserv_password});
				schedule sub {
					out irc => 1, "NICK $config{irc_nick}";
				} => 1;
				return; # we'll get here again for the NICK success message, or for a 433 failure
			}
			# otherwise, we failed to ghost and will continue with the wrong
			# nick... also, no need to try to identify here
		}
	}

	# we are on Quakenet. Try to authenticate.
	if(length $config{irc_quakenet_password} and length $config{irc_quakenet_authname})
	{
		if(defined $store{irc_quakenet_challenge})
		{
			if($store{irc_quakenet_challenge} =~ /^([0-9a-f]*)\b.*\bHMAC-SHA-256\b/)
			{
				my $challenge = $1;
				my $hash1 = Digest::SHA::sha256_hex(substr $config{irc_quakenet_password}, 0, 10);
				my $key = Digest::SHA::sha256_hex("@{[lc $config{irc_quakenet_authname}]}:$hash1");
				my $digest = Digest::HMAC::hmac_hex($challenge, $key, \&Digest::SHA::sha256);
				out irc => 1, "$config{irc_quakenet_challengeauth} $config{irc_quakenet_authname} $digest HMAC-SHA-256";
			}
		}
		else
		{
			out irc => 1, $config{irc_quakenet_getchallenge};
			return;
			# we get here again when Q asks us
		}
	}
	
	# if we get here, we are on IRC
	$store{irc_joined_channel} = 1;
	schedule sub {
		out irc => 1, "JOIN $config{irc_channel}";
	} => 1;
	return 0;
}

my $RE_FAIL = qr/$ $/;
my $RE_SUCCEED = qr//;
sub cond($)
{
	return $_[0] ? $RE_FAIL : $RE_SUCCEED;
}


# List of all handlers on the various sockets. Additional handlers can be added by a plugin.
@handlers = (
	# detect a server restart and set it up again
	[ dp => q{ *(?:Warning: Could not expand \$|Unknown command ")(?:rcon2irc_[a-z0-9_]*)[" ]*} => sub {
		out dp => 0,
			'alias rcon2irc_eval "$*"',
			'log_dest_udp',
			'sv_logscores_console 0',
			'sv_logscores_bots 1',
			'sv_eventlog 1',
			'sv_eventlog_console 1',
			'alias rcon2irc_say_as "set say_as_restorenick \"$sv_adminnick\"; sv_adminnick \"$1^3\"; say \"^7$2\"; rcon2irc_say_as_restore"',
			'alias rcon2irc_say_as_restore "set sv_adminnick \"$say_as_restorenick\""',
			'alias rcon2irc_quit "echo \"quitting rcon2irc $1: log_dest_udp is $log_dest_udp\""'; # note: \\\\\\" ->perl \\\" ->console \"
		return 0;
	} ],

	# detect missing entry in log_dest_udp and fix it
	[ dp => q{"log_dest_udp" is "([^"]*)" \["[^"]*"\]} => sub {
		my ($dest) = @_;
		my @dests = split ' ', $dest;
		return 0 if grep { $_ eq $config{dp_listen} } @dests;
		out dp => 0, 'log_dest_udp "' . join(" ", @dests, $config{dp_listen}) . '"';
		return 0;
	} ],

	# retrieve list of banned hosts
	[ dp => q{#(\d+): (\S+) is still banned for (\S+) seconds} => sub {
		return 0 unless $store{status_waiting} < 0;
		my ($id, $ip, $time) = @_;
		$store{bans_new} = [] if $id == 0;
		$store{bans_new}[$id] = { ip => $ip, 'time' => $time };
		return 0;
	} ],

	# retrieve hostname from status replies
	[ dp => q{host:     (.*)} => sub {
		return 0 unless $store{status_waiting} < 0;
		my ($name) = @_;
		$store{dp_hostname} = $name;
		$store{bans} = $store{bans_new};
		return 0;
	} ],

	# retrieve version from status replies
	[ dp => q{version:  (.*)} => sub {
		return 0 unless $store{status_waiting} < 0;
		my ($version) = @_;
		$store{dp_version} = $version;
		return 0;
	} ],

	# retrieve player names
	[ dp => q{players:  (\d+) active \((\d+) max\)} => sub {
		return 0 unless $store{status_waiting} < 0;
		my ($active, $max) = @_;
		my $full = ($active >= $max);
		$store{slots_max} = $max;
		$store{slots_active} = $active;
		$store{status_waiting} = $active;
		$store{playerslots_active_new} = [];
		if($store{status_waiting} == 0)
		{
			$store{playerslots_active} = $store{playerslots_active_new};
		}
		if($full != ($store{slots_full} || 0))
		{
			$store{slots_full} = $full;
			return 0 if $store{lms_blocked};
			return 0 if !$config{irc_announce_slotsfree};
			if($full)
			{
				out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION is full!\001";
			}
			else
			{
				my $slotsstr = nex_slotsstring();
				out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION can be joined again$slotsstr!\001";
			}
		}
		return 0;
	} ],

	# retrieve player names
	[ dp => q{\^\d(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(-?\d+)\s+\#(\d+)\s+\^\d(.*)} => sub {
		return 0 unless $store{status_waiting} > 0;
		my ($ip, $pl, $ping, $time, $frags, $no, $name) = ($1, $2, $3, $4, $5, $6, $7);
		$store{"playerslot_$no"} = { ip => $ip, pl => $pl, ping => $ping, 'time' => $time, frags => $frags, no => $no, name => $name };
		push @{$store{playerslots_active_new}}, $no;
		if(--$store{status_waiting} == 0)
		{
			$store{playerslots_active} = $store{playerslots_active_new};
		}
		return 0;
	} ],

	# IRC admin commands
	[ irc => q{:(([^! ]*)![^ ]*) (?i:PRIVMSG) [^&#%]\S* :(.*)} => sub {
		return 0 unless ($config{irc_admin_password} ne '' || $store{irc_quakenet_users});

		my ($hostmask, $nick, $command) = @_;
		my $dpnick = color_dpfix $nick;

		if($command eq "login $config{irc_admin_password}")
		{
			$store{logins}{$hostmask} = time() + $config{irc_admin_timeout};
			out irc => 0, "PRIVMSG $nick :my wish is your command";
			return -1;
		}

		if($command =~ /^login /)
		{
			out irc => 0, "PRIVMSG $nick :invalid password";
			return -1;
		}

		if(($store{logins}{$hostmask} || 0) < time())
		{
			out irc => 0, "PRIVMSG $nick :authentication required";
			return -1;
		}

		if($command =~ /^status(?: (.*))?$/)
		{
			my ($match) = $1;
			my $found = 0;
			my $foundany = 0;
			for my $slot(@{$store{playerslots_active} || []})
			{
				my $s = $store{"playerslot_$slot"};
				next unless $s;
				if(not defined $match or index(color_dp2none($s->{name}), $match) >= 0)
				{
					out irc => 0, sprintf 'PRIVMSG %s :%-21s %2i %4i %8s %4i #%-3u %s', $nick, $s->{ip}, $s->{pl}, $s->{ping}, $s->{time}, $s->{frags}, $slot, color_dp2irc $s->{name};
					++$found;
				}
				++$foundany;
			}
			if(!$found)
			{
				if(!$foundany)
				{
					out irc => 0, "PRIVMSG $nick :the server is empty";
				}
				else
				{
					out irc => 0, "PRIVMSG $nick :no nicknames match";
				}
			}
			return 0;
		}

		if($command =~ /^kick # (\d+) (.*)$/)
		{
			my ($id, $reason) = ($1, $2);
			my $dpreason = color_irc2dp $reason;
			$dpreason =~ s/^(~?)(.*)/$1irc $dpnick: $2/g;
			$dpreason =~ s/(["\\])/\\$1/g;
			out dp => 0, "kick # $id $dpreason";
			my $slotnik = "playerslot_$id";
			out irc => 0, "PRIVMSG $nick :kicked #$id (@{[color_dp2irc $store{$slotnik}{name}]}\017 @ $store{$slotnik}{ip}) ($reason)";
			return 0;
		}

		if($command =~ /^kickban # (\d+) (\d+) (\d+) (.*)$/)
		{
			my ($id, $bantime, $mask, $reason) = ($1, $2, $3, $4);
			my $dpreason = color_irc2dp $reason;
			$dpreason =~ s/^(~?)(.*)/$1irc $dpnick: $2/g;
			$dpreason =~ s/(["\\])/\\$1/g;
			out dp => 0, "kickban # $id $bantime $mask $dpreason";
			my $slotnik = "playerslot_$id";
			out irc => 0, "PRIVMSG $nick :kickbanned #$id (@{[color_dp2irc $store{$slotnik}{name}]}\017 @ $store{$slotnik}{ip}), netmask $mask, for $bantime seconds ($reason)";
			return 0;
		}

		if($command eq "bans")
		{
			my $banlist =
				join ", ",
				map { "$_ ($store{bans}[$_]{ip}, $store{bans}[$_]{time}s)" }
				0..@{$store{bans} || []}-1;
			$banlist = "no bans"
				if $banlist eq "";
			out irc => 0, "PRIVMSG $nick :$banlist";
			return 0;
		}

		if($command =~ /^unban (\d+)$/)
		{
			my ($id) = ($1);
			out dp => 0, "unban $id";
			out irc => 0, "PRIVMSG $nick :removed ban $id ($store{bans}[$id]{ip})";
			return 0;
		}

		if($command =~ /^mute (\d+)$/)
		{
			my $id = $1;
			out dp => 0, "mute $id";
			my $slotnik = "playerslot_$id";
			out irc => 0, "PRIVMSG $nick :muted $id (@{[color_dp2irc $store{$slotnik}{name}]}\017 @ $store{$slotnik}{ip})";
			return 0;
		}

		if($command =~ /^unmute (\d+)$/)
		{
			my ($id) = ($1);
			out dp => 0, "unmute $id";
			my $slotnik = "playerslot_$id";
			out irc => 0, "PRIVMSG $nick :unmuted $id (@{[color_dp2irc $store{$slotnik}{name}]}\017 @ $store{$slotnik}{ip})";
			return 0;
		}

		if($command =~ /^quote (.*)$/)
		{
			my ($cmd) = ($1);
			if($cmd =~ /^(??{$config{irc_admin_quote_re}})$/si)
			{
				out irc => 0, $cmd;
				out irc => 0, "PRIVMSG $nick :executed your command";
			}
			else
			{
				out irc => 0, "PRIVMSG $nick :permission denied";
			}
			return 0;
		}

		out irc => 0, "PRIVMSG $nick :unknown command (supported: status [substring], kick # id reason, kickban # id bantime mask reason, bans, unban banid, mute id, unmute id)";

		return -1;
	} ],

	# LMS: detect "no more lives" message
	[ dp => q{\^4.*\^4 has no more lives left} => sub {
		if(!$store{lms_blocked})
		{
			$store{lms_blocked} = 1;
			if(!$store{slots_full})
			{
				schedule sub {
					if($store{lms_blocked})
					{
						out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION can't be joined until next round (a player has no more lives left)\001";
					}
				} => 1;
			}
		}
	} ],

	# detect IRC errors and reconnect
	[ irc => q{ERROR .*} => \&irc_error ],
	[ irc => q{:[^ ]* 404 .*} => \&irc_error ], # cannot send to channel
	[ system => q{error irc} => \&irc_error ],

	# IRC nick in use
	[ irc => q{:[^ ]* 433 .*} => sub {
		return irc_joinstage(433);
	} ],

	# IRC welcome
	[ irc => q{:[^ ]* 001 .*} => sub {
		$store{irc_seen_welcome} = 1;
		$store{irc_nick} = $store{irc_nick_requested};
		return irc_joinstage(0);
	} ],

	# IRC my nickname changed
	[ irc => q{:(?i:(??{$store{irc_nick}}))![^ ]* (?i:NICK) :(.*)} => sub {
		my ($n) = @_;
		$store{irc_nick} = $n;
		return irc_joinstage(0);
	} ],

	# Quakenet: challenge from Q
	[ irc => q{(??{$config{irc_quakenet_challengeprefix}}) (.*)} => sub {
		$store{irc_quakenet_challenge} = $1;
		return irc_joinstage(0);
	} ],
	
	# Catch joins of people in a channel the bot is in and catch our own joins of a channel
	[ irc => q{:(([^! ]*)![^ ]*) JOIN (#.+)} => sub {
		my ($hostmask, $nick, $chan) = @_;
		return 0 unless ($store{irc_quakenet_users});
		
		if ($nick eq $config{irc_nick}) {
			out irc => 0, "PRIVMSG Q :users $chan"; # get auths for all users
		} else {
			$store{quakenet_hosts}->{$nick} = $hostmask;
			out irc => 0, "PRIVMSG Q :whois $nick"; # get auth for single user
		}
		
		return 0;
	} ],
	
	# Catch response of users request
	[ irc => q{:Q!TheQBot@CServe.quakenet.org NOTICE [^:]+ :[@\+\s]?(\S+)\s+(\S+)\s*(\S*)\s*\((.*)\)} => sub {
		my ($nick, $username, $flags, $host) = @_;
		return 0 unless ($store{irc_quakenet_users});
		
		$store{logins}{"$nick!$host"} = time() + 600 if ($store{irc_quakenet_users}->{$username});
		
		return 0;
	} ],
	
	# Catch response of whois request
	[ irc => q{:Q!TheQBot@CServe.quakenet.org NOTICE [^:]+ :-Information for user (.*) \(using account (.*)\):} => sub {
		my ($nick, $username) = @_;
		return 0 unless ($store{irc_quakenet_users});
		
		if ($store{irc_quakenet_users}->{$username}) {
			my $hostmask = $store{quakenet_hosts}->{$nick};
			$store{logins}{$hostmask} = time() + 600;
		}
		
		return 0;
	} ],

	# shut down everything on SIGINT
	[ system => q{quit (.*)} => sub {
		my ($cause) = @_;
		out irc => 1, "QUIT :$cause";
		$store{quitcookie} = int rand 1000000000;
		out dp => 0, "rcon2irc_quit $store{quitcookie}";
	} ],

	# remove myself from the log destinations and exit everything
	[ dp => q{quitting rcon2irc (??{$store{quitcookie}}): log_dest_udp is (.*) *} => sub {
		my ($dest) = @_;
		my @dests = grep { $_ ne $config{dp_listen} } split ' ', $dest;
		out dp => 0, 'log_dest_udp "' . join(" ", @dests) . '"';
		exit 0;
		return 0;
	} ],

	# IRC PING
	[ irc => q{PING (.*)} => sub {
		my ($data) = @_;
		out irc => 1, "PONG $data";
		return 1;
	} ],

	# IRC PONG
	[ irc => q{:[^ ]* PONG .* :(.*)} => sub {
		my ($data) = @_;
		return 0
			if not defined $store{irc_pingtime};
		return 0
			if $data ne $store{irc_pingtime};
		print "* measured IRC line delay: @{[time() - $store{irc_pingtime}]}\n";
		undef $store{irc_pingtime};
		return 0;
	} ],

	# detect channel join message and note hostname length to get the maximum allowed line length
	[ irc => q{(:(?i:(??{$store{irc_nick}}))![^ ]* )(?i:JOIN) :(?i:(??{$config{irc_channel}}))} => sub {
		$store{irc_maxlen} = 510 - length($1);
		$store{irc_joined_channel} = 1;
		print "* detected maximum line length for channel messages: $store{irc_maxlen}\n";
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel
	[ dp => q{\001(.*?)\^7: (.*)} => sub {
		my ($nick, $message) = map { color_dp2irc $_ } @_;
		out irc => 0, "PRIVMSG $config{irc_channel} :<$nick\017> $message";
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, nick set
	[ dp => q{:join:(\d+):(\d+):([^:]*):(.*)} => sub {
		my ($id, $slot, $ip, $nick) = @_;
		$store{"playernickraw_byid_$id"} = $nick;
		$nick = color_dp2irc $nick;
		$store{"playernick_byid_$id"} = $nick;
		$store{"playerip_byid_$id"} = $ip;
		$store{"playerslot_byid_$id"} = $slot;
		$store{"playerid_byslot_$slot"} = $id;
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, nick change/set
	[ dp => q{:name:(\d+):(.*)} => sub {
		my ($id, $nick) = @_;
		$store{"playernickraw_byid_$id"} = $nick;
		$nick = color_dp2irc $nick;
		my $oldnick = $store{"playernick_byid_$id"};
		out irc => 0, "PRIVMSG $config{irc_channel} :* $oldnick\017 is now known as $nick";
		$store{"playernick_byid_$id"} = $nick;
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, vote call
	[ dp => q{:vote:vcall:(\d+):(.*)} => sub {
		my ($id, $command) = @_;
		$command = color_dp2irc $command;
		my $oldnick = $id ? $store{"playernick_byid_$id"} : "(console)";
		out irc => 0, "PRIVMSG $config{irc_channel} :* $oldnick\017 calls a vote for \"$command\017\"";
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, vote stop
	[ dp => q{:vote:vstop:(\d+)} => sub {
		my ($id) = @_;
		my $oldnick = $id ? $store{"playernick_byid_$id"} : "(console)";
		out irc => 0, "PRIVMSG $config{irc_channel} :* $oldnick\017 stopped the vote";
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, master login
	[ dp => q{:vote:vlogin:(\d+)} => sub {
		my ($id) = @_;
		my $oldnick = $id ? $store{"playernick_byid_$id"} : "(console)";
		out irc => 0, "PRIVMSG $config{irc_channel} :* $oldnick\017 logged in as master";
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, master do
	[ dp => q{:vote:vdo:(\d+):(.*)} => sub {
		my ($id, $command) = @_;
		$command = color_dp2irc $command;
		my $oldnick = $id ? $store{"playernick_byid_$id"} : "(console)";
		out irc => 0, "PRIVMSG $config{irc_channel} :* $oldnick\017 used his master status to do \"$command\017\"";
		return 0;
	} ],

	# chat: Nexuiz server -> IRC channel, result
	[ dp => q{:vote:v(yes|no|timeout):(\d+):(\d+):(\d+):(\d+):(-?\d+)} => sub {
		my ($result, $yes, $no, $abstain, $not, $min) = @_;
		my $spam = "$yes:$no" . (($min >= 0) ? " ($min needed)" : "") . ", $abstain didn't care, $not didn't vote";
		out irc => 0, "PRIVMSG $config{irc_channel} :* the vote ended with $result: $spam";
		return 0;
	} ],

	# chat: IRC channel -> Nexuiz server
	[ irc => q{:([^! ]*)![^ ]* (?i:PRIVMSG) (?i:(??{$config{irc_channel}})) :(?i:(??{$store{irc_nick}}))(?: |: ?|, ?)(.*)} => sub {
		my ($nick, $message) = @_;
		$nick = color_dpfix $nick;
			# allow the nickname to contain colors in DP format! Therefore, NO color_irc2dp on the nickname!
		$message = color_irc2dp $message;
		$message =~ s/(["\\])/\\$1/g;
		out dp => 0, "rcon2irc_say_as \"$nick on IRC\" \"$message\"";
		return 0;
	} ],

	(
		length $config{irc_trigger}
			?
				[ irc => q{:([^! ]*)![^ ]* (?i:PRIVMSG) (?i:(??{$config{irc_channel}})) :(?i:(??{$config{irc_trigger}}))(?: |: ?|, ?)(.*)} => sub {
					my ($nick, $message) = @_;
					$nick = color_dpfix $nick;
						# allow the nickname to contain colors in DP format! Therefore, NO color_irc2dp on the nickname!
					$message = color_irc2dp $message;
					$message =~ s/(["\\])/\\$1/g;
					out dp => 0, "rcon2irc_say_as \"$nick on IRC\" \"$message\"";
					return 0;
				} ]
			:
				()
	),

	# irc: CTCP VERSION reply
	[ irc => q{:([^! ]*)![^ ]* (?i:PRIVMSG) (?i:(??{$store{irc_nick}})) :\001VERSION( .*)?\001} => sub {
		my ($nick) = @_;
		my $ver = $store{dp_version} or return 0;
		$ver .= ", rcon2irc $VERSION";
		out irc => 0, "NOTICE $nick :\001VERSION $ver\001";
	} ],

	# on game start, notify the channel
	[ dp => q{:gamestart:(.*):[0-9.]*} => sub {
		my ($map) = @_;
		$store{playing} = 1;
		$store{map} = $map;
		$store{map_starttime} = time();
		if ($config{irc_announce_mapchange} eq 'always' || ($config{irc_announce_mapchange} eq 'notempty' && $store{slots_active} > 0)) {
			my $slotsstr = nex_slotsstring();
			out irc => 0, "PRIVMSG $config{irc_channel} :\00304" . $map . "\017 has begun$slotsstr";
		}
		delete $store{lms_blocked};
		return 0;
	} ],

	# on game over, clear the current map
	[ dp => q{:gameover} => sub {
		$store{playing} = 0;
		return 0;
	} ],

	# scores: Nexuiz server -> IRC channel (start)
	[ dp => q{:scores:(.*):(\d+)} => sub {
		my ($map, $time) = @_;
		$store{scores} = {};
		$store{scores}{map} = $map;
		$store{scores}{time} = $time;
		$store{scores}{players} = [];
		delete $store{lms_blocked};
		return 0;
	} ],

	# scores: Nexuiz server -> IRC channel, legacy format
	[ dp => q{:player:(-?\d+):(\d+):(\d+):(\d+):(\d+):(.*)} => sub {
		my ($frags, $deaths, $time, $team, $id, $name) = @_;
		return if not exists $store{scores};
		push @{$store{scores}{players}}, [$frags, $team, $name]
			unless $frags <= -666; # no spectators
		return 0;
	} ],

	# scores: Nexuiz server -> IRC channel (CTF), legacy format
	[ dp => q{:teamscores:(\d+:-?\d*(?::\d+:-?\d*)*)} => sub {
		my ($teams) = @_;
		return if not exists $store{scores};
		$store{scores}{teams} = {split /:/, $teams};
		return 0;
	} ],

	# scores: Nexuiz server -> IRC channel, new format
	[ dp => q{:player:see-labels:(-?\d+)[-0-9,]*:(\d+):(\d+):(\d+):(.*)} => sub {
		my ($frags, $time, $team, $id, $name) = @_;
		return if not exists $store{scores};
		push @{$store{scores}{players}}, [$frags, $team, $name];
		return 0;
	} ],

	# scores: Nexuiz server -> IRC channel (CTF), new format
	[ dp => q{:teamscores:see-labels:(-?\d+)[-0-9,]*:(\d+)} => sub {
		my ($frags, $team) = @_;
		return if not exists $store{scores};
		$store{scores}{teams}{$team} = $frags;
		return 0;
	} ],

	# scores: Nexuiz server -> IRC channel
	[ dp => q{:end} => sub {
		return if not exists $store{scores};
		my $s = $store{scores};
		delete $store{scores};
		my $teams_matter = defined $s->{teams};

		my @t = ();
		my @p = ();

		if($teams_matter)
		{
			# put players into teams
			my %t = ();
			for(@{$s->{players}})
			{
				my $thisteam = ($t{$_->[1]} ||= {score => 0, team => $_->[1], players => []});
				push @{$thisteam->{players}}, [$_->[0], $_->[1], $_->[2]];
				if($s->{teams})
				{
					$thisteam->{score} = $s->{teams}{$_->[1]};
				}
				else
				{
					$thisteam->{score} += $_->[0];
				}
			}

			# sort by team score
			@t = sort { $b->{score} <=> $a->{score} } values %t;

			# sort by player score
			@p = ();
			for(@t)
			{
				@{$_->{players}} = sort { $b->[0] <=> $a->[0] } @{$_->{players}};
				push @p, @{$_->{players}};
			}
		}
		else
		{
			@p = sort { $b->[0] <=> $a->[0] } @{$s->{players}};
		}

		# no display for empty server
		return 0
			if !@p;

		# make message fit somehow
		for my $maxnamelen(reverse 3..64)
		{
			my $scores_string = "PRIVMSG $config{irc_channel} :\00304" . $s->{map} . "\017 ended:";
			if($teams_matter)
			{
				my $sep = ' ';
				for(@t)
				{
					$scores_string .= $sep . "\003" . $color_team2irc_table{$_->{team}}. "\002\002" . $_->{score} . "\017";
					$sep = ':';
				}
			}
			my $sep = '';
			for(@p)
			{
				my ($frags, $team, $name) = @$_;
				$name = color_dpfix substr($name, 0, $maxnamelen);
				if($teams_matter)
				{
					$name = "\003" . $color_team2irc_table{$team} . " " . color_dp2none $name;
				}
				else
				{
					$name = " " . color_dp2irc $name;
				}
				$scores_string .= "$sep$name\017 $frags";
				$sep = ',';
			}
			if(length($scores_string) <= ($store{irc_maxlen} || 256))
			{
				out irc => 0, $scores_string;
				return 0;
			}
		}
		out irc => 0, "PRIVMSG $config{irc_channel} :\001ACTION would have LIKED to put the scores here, but they wouldn't fit :(\001";
		return 0;
	} ],

	# complain when system load gets too high
	[ dp => q{timing:   (([0-9.]*)% CPU, ([0-9.]*)% lost, offset avg ([0-9.]*)ms, max ([0-9.]*)ms, sdev ([0-9.]*)ms)} => sub {
		my ($all, $cpu, $lost, $avg, $max, $sdev) = @_;
		return 0 # don't complain when just on the voting screen
			if !$store{playing};
		return 0 # don't complain if it was less than 0.5%
			if $lost < 0.5;
		return 0 # don't complain if nobody is looking
			if $store{slots_active} == 0;
		return 0 # don't complain in the first two minutes
			if time() - $store{map_starttime} < 120;
		return 0 # don't complain if it was already at least half as bad in this round
			if $store{map_starttime} == $store{timingerror_map_starttime} and $lost <= 2 * $store{timingerror_lost};
		$store{timingerror_map_starttime} = $store{map_starttime};
		$store{timingerror_lost} = $lost;
		out dp => 0, 'rcon2irc_say_as server "There are currently some severe system load problems. The admins have been notified."';
		out irc => 1, "PRIVMSG $config{irc_channel} :\001ACTION has big trouble on $store{map} after @{[int(time() - $store{map_starttime})]}s: $all\001";
		#out irc => 1, "PRIVMSG OpBaI :\001ACTION has big trouble on $store{map} after @{[int(time() - $store{map_starttime})]}s: $all\001";
		return 0;
	} ],
);



# Load plugins and add them to the handler list in the front.
for my $p(split ' ', $config{plugins})
{
	my @h = eval { do $p; }
		or die "Invalid plugin $p: $@";
	for(reverse @h)
	{
		ref $_ eq 'ARRAY' or die "Invalid plugin $p: did not return a list of arrays";
		@$_ == 3 or die "Invalid plugin $p: did not return a list of three-element arrays";
		!ref $_->[0] && !ref $_->[1] && ref $_->[2] eq 'CODE' or die "Invalid plugin $p: did not return a list of string-string-sub arrays";
		unshift @handlers, $_;
	}
}


# If users for quakenet are listed, parse them into a hash and schedule a sub to query information
if ($config{irc_quakenet_authusers} ne '') {
	$store{irc_quakenet_users} = { map { $_ => 1 } split / /, $config{irc_quakenet_authusers} };
	
	schedule sub {
		my ($timer) = @_;
		out irc => 0, "PRIVMSG Q :users " . $config{irc_channel};
		schedule $timer => 300;;
	} => 1;
}


# verify that the server is up by letting it echo back a string that causes
# re-initialization of the required aliases
out dp => 0, 'echo "Unknown command \"rcon2irc_eval\""'; # assume the server has been restarted



# regularily, query the server status and if it still is connected to us using
# the log_dest_udp feature. If not, we will detect the response to this rcon
# command and re-initialize the server's connection to us (either by log_dest_udp
# not containing our own IP:port, or by rcon2irc_eval not being a defined command).
schedule sub {
	my ($timer) = @_;
	out dp => 0, 'sv_cmd bans', 'status 1', 'log_dest_udp', 'rcon2irc_eval set dummy 1';
	$store{status_waiting} = -1;
	schedule $timer => (exists $store{dp_hostname} ? $config{dp_status_delay} : 1);;
} => 1;



# Continue with connecting to IRC as soon as we get our first status reply from
# the DP server (which contains the server's hostname that we'll use as
# realname for IRC).
schedule sub {
	my ($timer) = @_;

	# log on to IRC when needed
	if(exists $store{dp_hostname} && !exists $store{irc_logged_in})
	{
		$store{irc_nick_requested} = $config{irc_nick};
		out irc => 1, "NICK $config{irc_nick}", "USER $config{irc_user} localhost localhost :$store{dp_hostname}";
		$store{irc_logged_in} = 1;
		undef $store{irc_maxlen};
		undef $store{irc_pingtime};
	}

	schedule $timer => 1;;
} => 1;



# Regularily ping the IRC server to detect if the connection is down. If it is,
# schedule an IRC error that will cause reconnection later.
schedule sub {
	my ($timer) = @_;

	if($store{irc_logged_in})
	{
		if(defined $store{irc_pingtime})
		{
			# IRC connection apparently broke
			# so... KILL IT WITH FIRE
			$channels{system}->send("error irc", 0);
		}
		else
		{
			# everything is fine, send a new ping
			$store{irc_pingtime} = time();
			out irc => 1, "PING $store{irc_pingtime}";
		}
	}

	schedule $timer => $config{irc_ping_delay};;
} => 1;



# Main loop.
for(;;)
{
	# Build up an IO::Select object for all our channels.
	my $s = IO::Select->new();
	for my $chan(values %channels)
	{
		$s->add($_) for $chan->fds();
	}

	# wait for something to happen on our sockets, or wait 2 seconds without anything happening there
	$s->can_read(2);
	my @errors = $s->has_exception(0);

	# on every channel, look for incoming messages
	CHANNEL:
	for my $chanstr(keys %channels)
	{
		my $chan = $channels{$chanstr};
		my @chanfds = $chan->fds();

		for my $chanfd(@chanfds)
		{
			if(grep { $_ == $chanfd } @errors)
			{
				# STOP! This channel errored!
				$channels{system}->send("error $chanstr", 0);
				next CHANNEL;
			}
		}

		eval
		{
			for my $line($chan->recv())
			{
				# found one! Check if it matches the regular expression of one of
				# our handlers...
				my $handled = 0;
				my $private = 0;
				for my $h(@handlers)
				{
					my ($chanstr_wanted, $re, $sub) = @$h;
					next
						if $chanstr_wanted ne $chanstr;
					use re 'eval';
					my @matches = ($line =~ /^$re$/s);
					no re 'eval';
					next
						unless @matches;
					# and if it is a match, handle it.
					++$handled;
					my $result = $sub->(@matches);
					$private = 1
						if $result < 0;
					last
						if $result;
				}
				# print the message, together with info on whether it has been handled or not
				if($private)
				{
					print "           $chanstr >> (private)\n";
				}
				elsif($handled)
				{
					print "           $chanstr >> $line\n";
				}
				else
				{
					print "unhandled: $chanstr >> $line\n";
				}
			}
			1;
		} or do {
			if($@ eq "read error\n")
			{
				$channels{system}->send("error $chanstr", 0);
				next CHANNEL;
			}
			else
			{
				# re-throw
				die $@;
			}
		};
	}

	# handle scheduled tasks...
	my @t = @tasks;
	my $t = time();
	# by emptying the list of tasks...
	@tasks = ();
	for(@t)
	{
		my ($time, $sub) = @$_;
		if($t >= $time)
		{
			# calling them if they are schedled for the "past"...
			$sub->($sub);
		}
		else
		{
			# or re-adding them to the task list if they still are scheduled for the "future"
			push @tasks, [$time, $sub];
		}
	}
}
