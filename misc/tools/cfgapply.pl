#!/usr/bin/perl

use strict;
use warnings;

my %cvar2line = ();
my @lines = ();

my $first = 1;
while(<>)
{
	chomp;
	s/\r//g;

	if(/^\s*(?:set\s+|seta\s+)(\S+)/ or /^\s*(\S+_\S+)/)
	{
		if(exists $cvar2line{$1})
		{
			$lines[$cvar2line{$1}] = $_;
		}
		else
		{
			$cvar2line{$1} = scalar @lines;
			push @lines, $_;
		}
	}
	elsif($first) # only take comments, empty lines from the first config
	{
		push @lines, $_;
	}
	$first = 0
		if eof;
}

print "$_\n" for @lines;
