#!/usr/bin/perl

# no warranty for this script
# and no documentation
# take it or leave it

use strict;
use warnings;
use FindBin; use lib $FindBin::Bin;
use WeaponEncounterProfile;

my ($statsfile) = @ARGV;
my $stats;

sub LoadData()
{
	$stats = WeaponEncounterProfile->new($statsfile);
}

sub LinSolve($$)
{
	my ($m, $v) = @_;
	my $n = @$m;

	my @out = ();

	my @bigmatrix = map { [ @{$m->[$_]}, $v->[$_] ] } 0..$n-1;

	# 1. Triangulate
	for my $i(0..$n-1)
	{
		# first: bring the highest value to the top
		my $best = -1;
		my $bestval = 0;
		for my $j($i..$n-1)
		{
			my $v = $bigmatrix[$j]->[$i];
			if($v*$v > $bestval*$bestval)
			{
				$best = $j;
				$bestval = $v;
			}
		}
		die "lindep" if $best == -1;

		# swap
		($bigmatrix[$i], $bigmatrix[$best]) = ($bigmatrix[$best], $bigmatrix[$i]);

		# then: eliminate
		for my $j($i+1..$n-1)
		{
			my $r = $bigmatrix[$j]->[$i];
			for my $k(0..$n)
			{
				$bigmatrix[$j]->[$k] -= $bigmatrix[$i]->[$k] * $r / $bestval;
			}
		}
	}

	# 2. Diagonalize
	for my $i(reverse 0..$n-1)
	{
		my $bestval = $bigmatrix[$i]->[$i];
		for my $j(0..$i-1)
		{
			my $r = $bigmatrix[$j]->[$i];
			for my $k(0..$n)
			{
				$bigmatrix[$j]->[$k] -= $bigmatrix[$i]->[$k] * $r / $bestval;
			}
		}
	}

	# 3. Read off solutions
	return map { $bigmatrix[$_]->[$n] / $bigmatrix[$_]->[$_] } 0..($n-1);
}

sub SolveBestSquares($$)
{
	my ($d, $w) = @_;

	my $n = @$d;

	if($ENV{stupid})
	{
		my @result = ();
		for my $i(0..$n-1)
		{
			my $num = 0;
			my $denom = 0;
			for my $j(0..$n-1)
			{
				my $weight = $w->[$i]->[$j];
				$num += $weight * $d->[$i]->[$j];
				$denom += $weight;
			}
			push @result, $num / $denom;
		}
		return @result;
	}

	# build linear equation system

	my @matrix = map { [ map { 0 } 1..$n ] } 1..$n;
	my @vector = map { 0 } 1..$n;

	for my $i(0..$n-1)
	{
		$matrix[0][$i] += 1;
	}
	$vector[0] += 0;
	for my $z(1..$n-1)
	{
		for my $i(0..$n-1)
		{
			$matrix[$z][$i] += $w->[$i]->[$z];
			$matrix[$z][$z] -= $w->[$i]->[$z];
			$vector[$z] += $w->[$i]->[$z] * $d->[$i]->[$z];
		}
	}

	return LinSolve(\@matrix, \@vector);
}

sub Evaluate($)
{
	my ($matrix) = @_;
	my %allweps;
	while(my ($k, $v) = each %$matrix)
	{
		for(my ($k2, $v2) = each %$v)
		{
			next if $k eq $k2;
			next if !$v2;
			++$allweps{$k};
			++$allweps{$k2};
		}
	}
	delete $allweps{0}; # ignore the tuba
	my @allweps = keys %allweps;
	my %values;

	my @dmatrix = map { [ map { 0 } @allweps ] } @allweps;
	my @wmatrix = map { [ map { 0 } @allweps ] } @allweps;

	for my $i(0..@allweps - 1)
	{
		my $attackweapon = $allweps[$i];
		my $v = 0;
		my $d = 0;
		for my $j(0..@allweps - 1)
		{
			my $defendweapon = $allweps[$j];
			next if $attackweapon eq $defendweapon;
			my $win = ($matrix->{$attackweapon}{$defendweapon} || 0);
			my $lose = ($matrix->{$defendweapon}{$attackweapon} || 0);
			my $c = ($win + $lose);
			next if $c == 0;
			my $p = $win / $c;
			my $w = 1 - 1/($c * 0.1 + 1);

			$dmatrix[$i][$j] = $p - (1 - $p); # antisymmetric
			$wmatrix[$i][$j] = $w;            # symmetric
		}
	}

	my @val;
	eval
	{
		@val = SolveBestSquares(\@dmatrix, \@wmatrix);
		1;
	}
	or do
	{
		@val = map { undef } @allweps;
	};

	for my $i(0..@allweps - 1)
	{
		my $attackweapon = $allweps[$i];
		$values{$attackweapon} = $val[$i];
	}
	return \%values;
}

sub out_text($@)
{
	my ($event, @data) = @_;
	if($event eq 'start')
	{
	}
	elsif($event eq 'startmatrix')
	{
		my ($addr, $map, @columns) = @data;
		$addr ||= 'any';
		$map ||= 'any';
		print "For server @{[$addr || 'any']} map @{[$map || 'any']}:\n";
	}
	elsif($event eq 'startrow')
	{
		my ($row, $val) = @data;
		printf "  %-30s %8s |", $stats->weaponid_to_name($row), defined $val ? sprintf("%8.5f", $val) : "N/A";
	}
	elsif($event eq 'cell')
	{
		my ($win, $lose, $p) = @data;
		if(!defined $p)
		{
			print "   .   ";
		}
		elsif(!$p)
		{
			printf " %6.3f", 0;
		}
		else
		{
			printf " %+6.3f", $p;
		}
	}
	elsif($event eq 'endrow')
	{
		print "\n";
	}
	elsif($event eq 'endmatrix')
	{
		my ($min) = @data;
		$min ||= 0;
		print "  Relevance: $min\n";
		print "\n";
	}
	elsif($event eq 'end')
	{
	}
}

sub out_html($@)
{
	my ($event, @data) = @_;
	if($event eq 'start')
	{
		print "<html><body><h1>Weapon Profiling</h1>\n";
	}
	elsif($event eq 'startmatrix')
	{
		my ($addr, $map, @columns) = @data;
		$addr ||= 'any';
		$map ||= 'any';
		print "<h2>For server @{[$addr || 'any']} map @{[$map || 'any']}:</h2>\n";
		print "<table><tr><th>Weapon</th><th>Rating</th>\n";
		printf '<th><img width=70 height=80 src="http://svn.icculus.org/*checkout*/nexuiz/trunk/Docs/htmlfiles/weaponimg/thirdperson-%s.png" alt="%s"></th>', $stats->weaponid_to_model($_), $stats->weaponid_to_name($_) for @columns;
		print "</tr>\n";
	}
	elsif($event eq 'startrow')
	{
		my ($row, $val) = @data;
		printf '<tr><th><img width=108 height=53 src="http://svn.icculus.org/*checkout*/nexuiz/trunk/Docs/htmlfiles/weaponimg/firstperson-%s.png" alt="%s"></th><th align=right>%s</th>', $stats->weaponid_to_model($row), $stats->weaponid_to_name($row), defined $val ? sprintf("%8.5f", $val) : "N/A";
	}
	elsif($event eq 'cell')
	{
		my ($win, $lose, $p) = @data;
		my $v = 200;
		if(!defined $p)
		{
			printf '<td align=center bgcolor="#808080">%d</td>', $win;
		}
		elsif($p > 0)
		{
			printf '<td align=center bgcolor="#%02x%02x%02x">%d</td>', $v - $v * $p, 255, 0, $win;
		}
		elsif($p < 0)
		{
			#printf '<td align=center bgcolor="#%02x%02x%02x">%d</td>', (255 - $v) - $v * $p, $v + $v * $p, 0, $win;
			printf '<td align=center bgcolor="#%02x%02x%02x">%d</td>', 255, $v + $v * $p, 0, $win;
		}
		else
		{
			printf '<td align=center bgcolor="#ffff00">%d</td>', $win;
		}
	}
	elsif($event eq 'endrow')
	{
		print "</tr>";
	}
	elsif($event eq 'endmatrix')
	{
		my ($min) = @data;
		$min ||= 0;
		print "</table>Relevance: $min\n";
	}
	elsif($event eq 'end')
	{
	}
}

my $out = $ENV{html} ? \&out_html : \&out_text;

LoadData();
$out->(start => ());
$stats->allstats(sub
{
	my ($addr, $map, $data) = @_;
	my $values = Evaluate $data;
	my $valid = defined [values %$values]->[0];
	my @weapons_sorted = sort { $valid ? $values->{$b} <=> $values->{$a} : $a <=> $b } keys %$values;
	my $min = undef;
	$out->(startmatrix => ($addr, $map, @weapons_sorted));
	for my $row(@weapons_sorted)
	{
		$out->(startrow => $row, ($valid ? $values->{$row} : undef));
		for my $col(@weapons_sorted)
		{
			my $win = ($data->{$row}{$col} || 0);
			my $lose = ($data->{$col}{$row} || 0);
			$min = $win + $lose
				if $row ne $col and (not defined $min or $min > $win + $lose);
			$out->(cell => ($win, $lose, (($row ne $col) && ($win + $lose)) ? (2 * $win / ($win + $lose) - 1) : undef));
		}
		$out->(endrow => ());
	}
	$out->(endmatrix => ($min));
});
$out->(end => ());
