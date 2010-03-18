#!/usr/bin/perl

# usage:
#   ./democonv-15-20.pl infile outfile

use strict;
use warnings;

# constants
my $svc_print = "\010";
my $svc_serverinfo = "\013";

my %maps = (
	nexdm01 => 'basement',
	nexdm02 => 'bleach',
	nexdm03 => 'slimepit',
	nexdm04 => 'skyway',
	nexdm05 => 'downer',
	nexdm06 => 'starship',
	nexdm07 => 'dsi',
	nexdm08 => 'glowarena',
	nexdm09 => 'aneurysm',
	nexdm10 => 'stormkeep',
	nexdm11 => 'ruinsofslaughter',
	nexdm12 => 'evilspace',
	nexdm13 => 'dismal',
	nexdm14 => 'soylent',
	nexdm15 => 'oilrig',
	nexdm16 => 'silvercity',
	nexdm17 => 'dieselpower',
	nexdm18 => 'runningman',
	nexdm18_1on1remix => 'runningman_1on1remix',
	nexdmextra1 => 'darkzone',
	nexdmextra2 => 'aggressor',
	nexctf01 => 'basementctf',
	nexctf02 => 'runningmanctf',
);

# opening the files

push @ARGV, "$ARGV[0]-converted.dem"
	if @ARGV == 1;

die "Usage: $0 infile outfile"
	if @ARGV != 2;
my ($in, $out) = @ARGV;

$in ne $out
	or die "Input and output file may not be the same!";

open my $infh, "<", $in
	or die "open $in: $!";
binmode $infh;

open my $outfh, ">", $out
	or die "open $out: $!";
binmode $outfh;

sub TranslateMapname($)
{
	my ($map) = @_;
	return $maps{$map}
		if exists $maps{$map};
	return $map;
}

# 1. CD track

$/ = "\012";
my $cdtrack = <$infh>;
print $outfh $cdtrack;

# 2. packets

for(;;)
{
	last
		unless 4 == read $infh, my $length, 4;
	$length = unpack("V", $length);
	die "Invalid demo packet"
		unless 12 == read $infh, my $angles, 12;
	die "Invalid demo packet"
		unless $length == read $infh, my($data), $length;

	$data =~ s{
		^
		($svc_print
			[^\0]*\0
		$svc_serverinfo....
			[^\0]*\0
			maps/)([^\0]*)(\.bsp\0)
	}{$1 . TranslateMapname($2) . $3}sex;

	print $outfh pack("V", length $data);
	print $outfh $angles;
	print $outfh $data;
}

close $outfh;
close $infh;
