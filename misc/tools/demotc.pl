#!/usr/bin/perl

# Fake demo "cutting" tool
# works by looking for time codes in the demo
# and injecting playback speed commands

use strict;
use warnings;

sub sanitize($)
{
	my ($str) = @_;
	$str =~ y/\000-\037//d;
	return $str;
}

# opening the files

my ($in, $out, $tc0, $tc1, $pattern, $capture);

my $mode = shift @ARGV;
$mode = 'help' if not defined $mode;

if($mode eq 'grep' && @ARGV == 2)
{
	$in = $ARGV[0];
	$pattern = $ARGV[1];
}
elsif($mode eq 'uncut' && @ARGV == 2)
{
	$in = $ARGV[0];
	$out = $ARGV[1];
}
elsif($mode eq 'cut' && (@ARGV == 4 || @ARGV == 5))
{
	$in = $ARGV[0];
	$out = $ARGV[1];
	$tc0 = $ARGV[2];
	$tc1 = $ARGV[3];
	$capture = (@ARGV == 5);
}
else
{
	die "Usage: $0 cut infile outfile tc_start tc_end [--capture], or $0 uncut infile outfile, or $0 grep infile pattern\n"
}

if($mode ne 'grep')
{
	$in ne $out
		or die "Input and output file may not be the same!";
}

open my $infh, "<", $in
	or die "open $in: $!";
binmode $infh;

my $outfh;
if($mode ne 'grep') # cutting
{
	open $outfh, ">", $out
		or die "open $out: $!";
	binmode $outfh;
}

# 1. CD track

$/ = "\012";
my $cdtrack = <$infh>;
print $outfh $cdtrack if $mode ne 'grep';

# 2. packets

my $tc = undef;

my $first = 1;
my $demo_started = 0;
my $demo_stopped = 0;
my $inject_buffer = "";

use constant DEMOMSG_CLIENT_TO_SERVER => 0x80000000;
for(;;)
{
	last
		unless 4 == read $infh, my $length, 4;
	$length = unpack("V", $length);
	if($length & DEMOMSG_CLIENT_TO_SERVER)
	{
		# client-to-server packet
		$length = $length & ~DEMOMSG_CLIENT_TO_SERVER;
		die "Invalid demo packet"
			unless 12 == read $infh, my $angles, 12;
		die "Invalid demo packet"
			unless $length == read $infh, my($data), $length;

		next if $mode eq 'grep';
		print $outfh pack("V", length($data) | DEMOMSG_CLIENT_TO_SERVER);
		print $outfh $angles;
		print $outfh $data;
		next;
	}
	die "Invalid demo packet"
		unless 12 == read $infh, my $angles, 12;
	die "Invalid demo packet"
		unless $length == read $infh, my($data), $length;
	
	# remove existing cut marks
	$data =~ s{^\011\n//CUTMARK\n[^\0]*\0}{};
	
	if(substr($data, 0, 1) eq "\007") # svc_time
	{
		$tc = unpack "f", substr $data, 1, 4;
	}

	if($mode eq 'cut' && defined $tc)
	{
		if($first)
		{
			$inject_buffer = "\011\n//CUTMARK\nslowmo 100\n\000";
			$first = 0;
		}
		if($demo_started < 1 && $tc > $tc0 - 50)
		{
			$inject_buffer = "\011\n//CUTMARK\nslowmo 10\n\000";
			$demo_started = 1;
		}
		if($demo_started < 2 && $tc > $tc0 - 5)
		{
			$inject_buffer = "\011\n//CUTMARK\nslowmo 1\n\000";
			$demo_started = 2;
		}
		if($demo_started < 3 && $tc > $tc0)
		{
			if($capture)
			{
				$inject_buffer = "\011\n//CUTMARK\ncl_capturevideo 1\n\000";
			}
			else
			{
				$inject_buffer = "\011\n//CUTMARK\nslowmo 0; defer 1 \"slowmo 1\"\n\000";
			}
			$demo_started = 3;
		}
		if(!$demo_stopped && $tc > $tc1)
		{
			if($capture)
			{
				$inject_buffer = "\011\n//CUTMARK\ncl_capturevideo 0; defer 0.5 \"disconnect\"\n\000";
			}
			else
			{
				$inject_buffer = "\011\n//CUTMARK\ndefer 0.5 \"disconnect\"\n\000";
			}
			$demo_stopped = 1;
		}
	}
	elsif($mode eq 'grep')
	{
		if(my @l = ($data =~ /$pattern/))
		{
			if(defined $tc)
			{
				print "$tc:";
			}
			else
			{
				print "start:";
			}
			for(@l)
			{
				print " \"", sanitize($_), "\"";
			}
			print "\n";
		}
	}
	
	next if $mode eq 'grep';
	if(length($inject_buffer . $data) < 65536)
	{
		$data = $inject_buffer . $data;
		$inject_buffer = "";
	}
	print $outfh pack("V", length $data);
	print $outfh $angles;
	print $outfh $data;
}

close $outfh if $mode ne 'grep';
close $infh;
