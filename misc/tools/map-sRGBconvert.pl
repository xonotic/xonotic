#!/usr/bin/perl

use strict;
use warnings;

my @defaultkeys = qw/_color _floodlight/;

my @colorkeys = @ARGV;
@colorkeys = '+'
	if @colorkeys == 0;
@colorkeys = map { $_ eq '-' ? map { "-$_" } @defaultkeys : $_ eq '+' ? @defaultkeys : $_ } @colorkeys;
print STDERR "Remapping keys: @colorkeys\n";

sub Image_LinearFloatFromsRGBFloat($) {($_[0] <= 0.04045) ? $_[0] * (1.0 / 12.92) : (($_[0] + 0.055)*(1.0/1.055)) ** 2.4}
sub Image_sRGBFloatFromLinearFloat($) {($_[0] < 0.0031308) ? $_[0] * 12.92 : 1.055 * ($_[0] ** (1.0/2.4)) - 0.055}

while(<STDIN>)
{
	chomp;
	my $line = $_;
	if(/^\s*"([^"]*)"\s+"\s*([-+0-9.]+)\s*([-+0-9.]+)\s*([-+0-9.]+)\s*"\s*$/i)
	{
		my $key = $1;
		my $r = $2;
		my $g = $3;
		my $b = $4;
		if(grep { /^\+?\Q$key\E$/i } @colorkeys)
		{
			$r = Image_LinearFloatFromsRGBFloat $r;
			$g = Image_LinearFloatFromsRGBFloat $g;
			$b = Image_LinearFloatFromsRGBFloat $b;
			$line = "\"$key\" \"$r $g $b\"";
		}
		elsif(grep { /^-\Q$key\E$/i } @colorkeys)
		{
			$r = Image_sRGBFloatFromLinearFloat $r;
			$g = Image_sRGBFloatFromLinearFloat $g;
			$b = Image_sRGBFloatFromLinearFloat $b;
			$line = "\"$key\" \"$r $g $b\"";
		}
	}
	elsif(/^\s*"_floodlight"\s+"\s*([-+0-9.]+)\s*([-+0-9.]+)\s*([-+0-9.]+)(\s*.*)"\s*$/i)
	{
		my $r = $1;
		my $g = $2;
		my $b = $3;
		my $rest = $4;
		if(grep { /^\+?_floodlight$/i } @colorkeys)
		{
			$r = 255.0*Image_LinearFloatFromsRGBFloat($r/255.0);
			$g = 255.0*Image_LinearFloatFromsRGBFloat($g/255.0);
			$b = 255.0*Image_LinearFloatFromsRGBFloat($b/255.0);
			$line = "\"_floodlight\" \"$r $g $b$rest\"";
		}
		elsif(grep { /^-_floodlight$/i } @colorkeys)
		{
			$r = 255.0*Image_sRGBFloatFromLinearFloat($r/255.0);
			$g = 255.0*Image_sRGBFloatFromLinearFloat($g/255.0);
			$b = 255.0*Image_sRGBFloatFromLinearFloat($b/255.0);
			$line = "\"_floodlight\" \"$r $g $b$rest\"";
		}
	}
	if($line ne $_)
	{
		print STDERR "Converting: $_ -> $line\n";
		$_ = $line;
	}
	print "$_\n";
}
