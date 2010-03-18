#!/usr/bin/perl

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

# parts copied from rcon2irc
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







package main;
use strict;
use warnings;
use IO::Select;
use Time::HiRes;

sub default($$)
{
	my ($default, $value) = @_;
	return $value if defined $value;
	return $default;
}

my $server   = default '',       $ENV{rcon_address};
my $password = default '',       $ENV{rcon_password};
my $secure   = default '1',      $ENV{rcon_secure};
my $timeout  = default '5',      $ENV{rcon_timeout};
my $timeouti = default '0.2',    $ENV{rcon_timeout_inter};
my $timeoutc = default $timeout, $ENV{rcon_timeout_challenge};
my $colors   = default '0',      $ENV{rcon_colorcodes_raw};

if(!length $server)
{
	print STDERR "Usage: rcon_address=SERVERIP:PORT rcon_password=PASSWORD $0 rconcommands...\n";
	print STDERR "Optional: rcon_timeout=... (default: 5)\n";
	print STDERR "          rcon_timeout_inter=... (default: 0.2)\n";
	print STDERR "          rcon_timeout_challenge=... (default: 5)\n";
	print STDERR "          rcon_colorcodes_raw=1 (to disable color codes translation)\n";
	print STDERR "          rcon_secure=0 (to allow connecting to older servers not supporting secure rcon)\n";
	exit 0;
}

my $connection = Connection::Socket->new("udp", "", $server, 26000);
my $rcon = Channel::QW->new($connection, $password, $secure, $timeoutc);

if(!$rcon->send($rcon->join_commands(@ARGV)))
{
	die "send: $!";
}

if($timeout > 0)
{
	my $sel = IO::Select->new($rcon->fds());
	my $endtime_max = Time::HiRes::time() + $timeout;
	my $endtime = $endtime_max;

	while((my $dt = $endtime - Time::HiRes::time()) > 0)
	{
		if($sel->can_read($dt))
		{
			for($rcon->recv())
			{
				$_ = (color_dp2ansi $_) . "\033[m" unless $colors;
				print "$_\n"
			}
			$endtime = Time::HiRes::time() + $timeouti;
			$endtime = $endtime_max
				if $endtime > $endtime_max;
		}
	}
}
exit 0;
