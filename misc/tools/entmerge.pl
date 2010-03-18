#!/usr/bin/perl

use strict;
use warnings;
use Carp;
$SIG{__DIE__} = sub { 
	Carp::cluck "Exception: $@";
};

# ent file managing tool
# usage:
#
#   map -> ent:
#     perl entmerge.pl $scalefactor             < mapname.map > mapname.ent
#
#   ent -> map:
#     perl entmerge.pl $scalefactor mapname.ent < mapname.map > mapname-merged.map
#
#   bsp -> ent:
#     perl bsptool.pl mapname.bsp -xentities                  > mapname.ent
#                                                          
#   ent -> bsp:                                            
#     perl bsptool.pl mapname.bsp -rentities                  < mapname.ent

sub DotProduct($$)
{
	my ($a, $b) = @_;
	return	$a->[0]*$b->[0]
		+	$a->[1]*$b->[1]
		+	$a->[2]*$b->[2];
}

sub CrossProduct($$)
{
	my ($a, $b) = @_;
	return	[
		$a->[1]*$b->[2] - $a->[2]*$b->[1],
		$a->[2]*$b->[0] - $a->[0]*$b->[2],
		$a->[0]*$b->[1] - $a->[1]*$b->[0]
	];
}

sub VectorMAM(@)
{
	my (@data) = @_;
	my $out = [0, 0, 0];
	for my $coord(0..2)
	{
		my $c = 0;
		$c += $data[2*$_ + 0] * $data[2*$_ + 1]->[$coord]
			for 0..(@data/2 - 1);
		$out->[$coord] = $c;
	}
	return $out;
}

sub VectorLength2($)
{
	my ($v) = @_;
	return DotProduct $v, $v;
}

sub VectorLength($)
{
	my ($v) = @_;
	return sqrt VectorLength2 $v;
}

sub VectorNormalize($)
{
	my ($v) = @_;
	return VectorMAM 1/VectorLength($v), $v;
}

sub Polygon_QuadForPlane($$)
{
	my ($plane, $quadsize) = @_;

	my $quadup;
	if(abs($plane->[2]) > abs($plane->[0]) && abs($plane->[2]) > abs($plane->[1]))
	{
		$quadup = [1, 0, 0];
	}
	else
	{
		$quadup = [0, 0, 1];
	}

	$quadup = VectorMAM 1, $quadup, -DotProduct($quadup, $plane), $plane;
	$quadup = VectorMAM $plane->[3], VectorNormalize $quadup;

	my $quadright = CrossProduct $quadup, $plane;

	return [
		VectorMAM($plane->[3], $plane, -$quadsize*2, $quadright, +$quadsize*2, $quadup),
		VectorMAM($plane->[3], $plane, +$quadsize*2, $quadright, +$quadsize*2, $quadup),
		VectorMAM($plane->[3], $plane, +$quadsize*2, $quadright, -$quadsize*2, $quadup),
		VectorMAM($plane->[3], $plane, -$quadsize*2, $quadright, -$quadsize*2, $quadup)
	];
}

sub Polygon_Clip($$$)
{
	my ($points, $plane, $epsilon) = @_;

	if(@$points < 1)
	{
		return [];
	}

	my $n = 0;
	my $ndist = DotProduct($points->[$n], $plane) - $plane->[3];

	my @outfrontpoints = ();

	for my $i(0..@$points - 1)
	{
		my $p = $n;
		my $pdist = $ndist;
		$n = ($i+1) % @$points;
		$ndist = DotProduct($points->[$n], $plane) - $plane->[3];
		if($pdist >= -$epsilon)
		{
			push @outfrontpoints, $points->[$p];
		}
		if(($pdist > $epsilon && $ndist < -$epsilon) || ($pdist < -$epsilon && $ndist > $epsilon))
		{
			my $frac = $pdist / ($pdist - $ndist);
			push @outfrontpoints, VectorMAM 1-$frac, $points->[$p], $frac, $points->[$n];
		}
	}

	return \@outfrontpoints;
}

sub MakePlane($$$)
{
	my ($p, $q, $r) = @_;

	my $a = VectorMAM 1, $q, -1, $p;
	my $b = VectorMAM 1, $r, -1, $p;
	my $n = VectorNormalize CrossProduct $a, $b;

	return [ @$n, DotProduct $n, $p ];
}

sub GetBrushWindings($)
{
	my ($planes) = @_;

	my @windings = ();

	for my $i(0..(@$planes - 1))
	{
		my $winding = Polygon_QuadForPlane $planes->[$i], 65536;

		for my $j(0..(@$planes - 1))
		{
			next
				if $i == $j;
			$winding = Polygon_Clip $winding, $planes->[$j], 1/64.0;
		}

		push @windings, $winding
			unless @$winding == 0;
	}

	return \@windings;
}

sub GetBrushMinMax($)
{
	my ($brush) = @_;

	if($brush->[0] =~ /^\(/)
	{
		# plain brush
		my @planes = ();
		for(@$brush)
		{
			/^\(\s+(\S+)\s+(\S+)\s+(\S+)\s+\)\s+\(\s+(\S+)\s+(\S+)\s+(\S+)\s+\)\s+\(\s+(\S+)\s+(\S+)\s+(\S+)\s+\)\s+/
				or die "Invalid line in plain brush: $_";
			push @planes, MakePlane [ $1, $2, $3 ], [ $4, $5, $6 ], [ $7, $8, $9 ];
			# for any three planes, find their intersection
			# check if the intersection is inside all other planes
		}
		
		my $windings = GetBrushWindings \@planes;

		my (@mins, @maxs);

		for(@$windings)
		{
			for my $v(@$_)
			{
				if(@mins)
				{
					for(0..2)
					{
						$mins[$_] = $v->[$_] if $mins[$_] > $v->[$_];
						$maxs[$_] = $v->[$_] if $maxs[$_] < $v->[$_];
					}
				}
				else
				{
					@mins = @$v;
					@maxs = @$v;
				}
			}
		}

		return undef
			unless @mins;
		return \@mins, \@maxs;
	}

	die "Cannot decode this brush yet! brush is @$brush";
}

sub BrushOrigin($)
{
	my ($brushes) = @_;

	my @org = ();

	for my $brush(@$brushes)
	{
		my $isorigin = 0;
		for(@$brush)
		{
			$isorigin = 1
				if /\bcommon\/origin\b/;
		}
		if($isorigin)
		{
			my ($mins, $maxs) = GetBrushMinMax $brush;
			@org = map { 0.5 * ($mins->[$_] + $maxs->[$_]) } 0..2
				if defined $mins;
		}
	}

	return \@org
		if @org;
	return undef;
}

sub ParseEntity($)
{
	my ($fh) = @_;

	my %ent = ( );
	my @brushes = ( );

	while(<$fh>)
	{
		chomp; s/\r//g; s/\0//g; s/\/\/.*$//; s/^\s+//; s/\s+$//; next if /^$/;

		if(/^\{$/)
		{
			# entity starts
			while(<$fh>)
			{
				chomp; s/\r//g; s/\0//g; s/\/\/.*$//; s/^\s+//; s/\s+$//; next if /^$/;

				if(/^"(.*?)" "(.*)"$/)
				{
					# key-value pair
					$ent{$1} = $2;
				}
				elsif(/^\{$/)
				{
					my $brush = [];
					push @brushes, $brush;

					while(<$fh>)
					{
						chomp; s/\r//g; s/\0//g; s/\/\/.*$//; s/^\s+//; s/\s+$//; next if /^$/;

						if(/^\{$/)
						{
							# patch?
							push @$brush, $_;

							while(<$fh>)
							{
								chomp; s/\r//g; s/\0//g; s/\/\/.*$//; s/^\s+//; s/\s+$//; next if /^$/;

								if(/^\}$/)
								{
									push @$brush, $_;

									last;
								}
								else
								{
									push @$brush, $_;
								}
							}
						}
						elsif(/^\}$/)
						{
							# end of brush
							last;
						}
						else
						{
							push @$brush, $_;
						}
					}
				}
				elsif(/^\}$/)
				{
					return \%ent, \@brushes;
				}
			}
		}
		else
		{
			die "Unexpected line in top level: >>$_<<";
		}
	}

	return undef;
}

sub UnparseEntity($$)
{
	my ($ent, $brushes) = @_;
	my %ent = %$ent;

	my $s = "{\n";

	for(sort keys %ent)
	{
		$s .= "\"$_\" \"$ent{$_}\"\n";
	}

	if(defined $brushes)
	{
		for(@$brushes)
		{
			$s .= "{\n";
			$s .= "$_\n" for @$_;
			$s .= "}\n";
		}
	}

	$s .= "}\n";
	return $s;
}

my ($scale, $in_ent) = @ARGV;

$scale = 1
	if not defined $scale;

my @submodels = ();
my @entities = ();
my @entities_skipped = ();

# THIS part is always a .map file
my $first = 1;
my $keeplights;
for(;;)
{
	my ($ent, $brushes) = ParseEntity \*STDIN;

	defined $ent
		or last;
	
	if($first && $ent->{classname} eq 'worldspawn')
	{
		$keeplights = $ent->{_keeplights};
		delete $ent->{_keeplights};
		@submodels = ($brushes);
	}
	else
	{
		if($first)
		{
			push @entities, { classname => "worldspawn" };
			@submodels = ([]);
		}

		if($ent->{classname} eq 'worldspawn')
		{
			$ent->{classname} = "worldspawn_renamed";
		}

		if(grep { $_ eq $ent->{classname} } qw/group_info func_group misc_model _decal _skybox/)
		{
			push @entities_skipped, [$ent, $brushes];
			next;
		}

		if(!$keeplights && $ent->{classname} =~ /^light/)
		{
			push @entities_skipped, [$ent, $brushes];
			next;
		}

		if(@$brushes)
		{
			my $i = @submodels;
			push @submodels, $brushes;
			$ent->{model} = sprintf "*%d", $i;
		}
	}

	push @entities, $ent;

	$first = 0;
}

if($first)
{
	push @entities, { classname => "worldspawn" };
	@submodels = ([]);
}

if(defined $in_ent)
{
	# translate map using ent to map
	open my $fh, "<", $in_ent
		or die "$in_ent: $!";

	# THIS part is always an .ent file now
	my @entities_entfile = ();
	$first = 1;
	
	my $clear_all_worldlights;

	for(;;)
	{
		my ($ent, $brushes) = ParseEntity $fh;

		defined $ent
			or last;
		
		if($first && $ent->{classname} eq 'worldspawn')
		{
		}
		else
		{
			if($first)
			{
				push @entities_entfile, { classname => "worldspawn" };
			}

			if($ent->{classname} eq 'worldspawn')
			{
				$ent->{classname} = "worldspawn_renamed";
			}

			if(!$keeplights && $ent->{classname} =~ /^light/)
			{
				# light entity detected!
				# so let's replace all light entities
				$clear_all_worldlights = 1;
			}
		}

		if(defined $ent->{model} and $ent->{model} =~ /^\*(\d+)$/)
		{
			my $entfileorigin = [ split /\s+/, ($ent->{origin} || "0 0 0") ];
			my $baseorigin = BrushOrigin $submodels[$1];

			if(defined $baseorigin)
			{
				my $org = VectorMAM 1, $entfileorigin, -1, $baseorigin;
				$ent->{origin} = sprintf "%.6f %.6f %.6f", @$org;
			}
		}

		push @entities_entfile, $ent;
		$first = 0;
	}
	close $fh;

	if($keeplights && !$entities_entfile[0]->{keeplights})
	{
		# PROBLEM:
		# the .ent file was made without keeplights
		# merging it with the .map would delete all lights
		# so insert all light entities here!
		@entities_skipped = (@entities_skipped,
			map
			{
				my $submodel = undef;
				if(defined $_->{model} and $_->{model} =~ /^\*(\d+)$/)
				{
					$submodel = $submodels[$1];
				}
				[ $_, $submodel ]
			}
			grep
			{
				$_->{classname} =~ /^light/
			}
			@entities
		);
	}

	if($clear_all_worldlights)
	{
		# PROBLEM:
		# the .ent file was made with keeplights
		# the .map did not indicate so!
		# so we must delete all lights from the skipped entity list
		@entities_skipped = grep { $_->[0]->{classname} !~ /^light/ } @entities_skipped;
	}

	if($first)
	{
		push @entities_entfile, { classname => "worldspawn" };
	}

	$first = 1;
	for(@entities_entfile)
	{
		my %e = %$_;
		my $submodel = undef;

		$e{gridsize} = "64 64 128" if not exists $e{gridsize} and $first;
		$e{lip} /= $scale if exists $e{lip};
		$e{origin} = sprintf '%.6f %.6f %.6f', map { $_ / $scale } split /\s+/, $e{origin} if exists $e{origin};
		$e{gridsize} = sprintf '%.6f %.6f %.6f', map { $_ / $scale } split /\s+/, $e{gridsize} if exists $e{gridsize} and $first;

		if($first)
		{
			$submodel = $submodels[0];
			if($keeplights)
			{
				$e{_keeplights} = 1;
			}
			else
			{
				delete $e{_keeplights};
			}
		}
		elsif(defined $e{model} and $e{model} =~ /^\*(\d+)$/)
		{
			$submodel = $submodels[$1];
			delete $e{model};
		}
		print UnparseEntity \%e, $submodel;
		$first = 0;
	}
	for(@entities_skipped)
	{
		print UnparseEntity $_->[0], $_->[1];
		$first = 0;
	}
}
else
{
	# translate map to ent
	$first = 1;
	for(@entities)
	{
		my %e = %$_;

		if($first)
		{
			if($keeplights)
			{
				$e{_keeplights} = 1;
			}
			else
			{
				delete $e{_keeplights};
			}
		}

		if(defined $e{model} and $e{model} =~ /^\*(\d+)$/)
		{
			my $oldorigin = [ split /\s+/, ($e{origin} || "0 0 0") ];
			my $org = BrushOrigin $submodels[$1];

			if(defined $org)
			{
				$org = VectorMAM 1, $org, 1, $oldorigin;
				$e{origin} = sprintf "%.6f %.6f %.6f", @$org;
			}
		}

		$e{gridsize} = "64 64 128" if not exists $e{gridsize} and $first;
		$e{lip} *= $scale if exists $e{lip};
		$e{origin} = sprintf '%.6f %.6f %.6f', map { $_ * $scale } split /\s+/, $e{origin} if exists $e{origin};
		$e{gridsize} = sprintf '%.6f %.6f %.6f', map { $_ * $scale } split /\s+/, $e{gridsize} if exists $e{gridsize} and $first;

		print UnparseEntity \%e, undef;
		$first = 0;
	}
}
