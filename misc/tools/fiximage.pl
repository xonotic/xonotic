#!/usr/bin/perl

use strict;
use warnings;

# Usage:
#   convert image.tga -depth 8 RGBA:- | perl fiximage.pl 72 | convert -depth 8 -size 72x56 RGBA:- output.tga

my ($width) = @ARGV;

my @pixels = ();

for(;;)
{
	read STDIN, my $data, 4
		or last;
	my ($r, $g, $b, $a) = unpack "CCCC", $data;
	push @pixels, [$r, $g, $b, $a];
}

my $height = @pixels / $width;
my @fixlater;
for my $y(0..($height-1))
{
	for my $x(0..($width-1))
	{
		next
			if $pixels[$x + $y * $width][3] != 0;
		# alpha is zero? Replace by weighted average.
		my ($r, $g, $b, $a) = (0, 0, 0);
		for my $dy(-1..1)
		{
			next if $y + $dy < 0;
			next if $y + $dy >= $height;
			for my $dx(-1..1)
			{
				next if $x + $dx < 0;
				next if $x + $dx >= $width;
				my $pix = $pixels[($x + $dx) + ($y + $dy) * $width];
				$r += $pix->[0] * $pix->[3];
				$g += $pix->[1] * $pix->[3];
				$b += $pix->[2] * $pix->[3];
				$a += $pix->[3];
			}
		}
		if($a == 0)
		{
			push @fixlater, [$x, $y];
			$pixels[$x + $y * $width] = [0, 0, 0, 0, undef];
			next;
		}
		$r = int ($r / $a);
		$g = int ($g / $a);
		$b = int ($b / $a);
		print STDERR "Fixing ($x, $y -> $r, $g, $b, $a)\n";
		$pixels[$x + $y * $width] = [$r, $g, $b, 0];
	}
}

while(@fixlater)
{
	print STDERR "Pixels left: ", scalar(@fixlater), "\n";

	# These pixels have no neighbors with a non-zero alpha.
	my @fixels = @fixlater;
	@fixlater = ();
	my @pixelsorig = @pixels;
	for(@fixels)
	{
		my ($x, $y) = @$_;
		my ($r, $g, $b, $a) = (0, 0, 0, 0);
		for my $dy(-1..1)
		{
			next if $y + $dy < 0;
			next if $y + $dy >= $height;
			for my $dx(-1..1)
			{
				next if $x + $dx < 0;
				next if $x + $dx >= $width;
				my $pix = $pixelsorig[($x + $dx) + ($y + $dy) * $width];
				next
					if @$pix == 5;
				$r += $pix->[0];
				$g += $pix->[1];
				$b += $pix->[2];
				$a += 1;
			}
		}
		if($a == 0)
		{
			push @fixlater, [$x, $y];
			next;
		}
		$r = int ($r / $a);
		$g = int ($g / $a);
		$b = int ($b / $a);
		#print STDERR "Fixing later ($x, $y -> $r, $g, $b, $a)\n";
		$pixels[$x + $y * $width] = [$r, $g, $b, 0];
	}
}

for(@pixels)
{
	print pack "CCCC", @$_;
}
