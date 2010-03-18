#!/usr/bin/perl

# script that creates an "assault circuit"

use strict;
use warnings;

my @objectives = @ARGV;

if(!@objectives)
{
	print STDERR <<EOF;
Assault Circuit Board Creator

Usage: 
  [brushprimit=1 \\]
  [ofs_x=offset \\]
  [ofs_y=offset \\]
  [ofs_z=offset \\]
  perl $0 breakables1[,buttons1] breakables2[,buttons2] breakables3[,buttons3] ... \\
  > file.map

Example:
  ofs_z=1024 perl $0 1 1 3,2 1 > assault.map
EOF
	exit 1;
}

my $bp = $ENV{brushprimit};
my @ofs = ($ENV{ofs_x} || 0, $ENV{ofs_y} || 0, $ENV{ofs_z} || 0);

my $BRUSHDEF_START = $bp ? "{\nbrushDef\n{" : "{";
my $BRUSHDEF_END   = $bp ? "}\n}" : "}";
my $BRUSHDEF_PRE   = $bp ? "( ( 0.03125 0 -0 ) ( -0 0.03125 0 ) ) " : "";
my $BRUSHDEF_POST  = $bp ? " 0 0 0" : " 0 0 0 0.500000 0.500000 0 0 0";

sub BrushRectangle($@@)
{
    my ($shader, $x0, $y0, $z0, $x1, $y1, $z1) = @_;
    return <<EOF;
$BRUSHDEF_START
( $x1 $y1 $z1 ) ( $x1 $y0 $z1 ) ( $x0 $y1 $z1 ) $BRUSHDEF_PRE$shader$BRUSHDEF_POST
( $x1 $y1 $z1 ) ( $x0 $y1 $z1 ) ( $x1 $y1 $z0 ) $BRUSHDEF_PRE$shader$BRUSHDEF_POST
( $x1 $y1 $z1 ) ( $x1 $y1 $z0 ) ( $x1 $y0 $z1 ) $BRUSHDEF_PRE$shader$BRUSHDEF_POST
( $x0 $y0 $z0 ) ( $x1 $y0 $z0 ) ( $x0 $y1 $z0 ) $BRUSHDEF_PRE$shader$BRUSHDEF_POST
( $x0 $y0 $z0 ) ( $x0 $y0 $z1 ) ( $x1 $y0 $z0 ) $BRUSHDEF_PRE$shader$BRUSHDEF_POST
( $x0 $y0 $z0 ) ( $x0 $y1 $z0 ) ( $x0 $y0 $z1 ) $BRUSHDEF_PRE$shader$BRUSHDEF_POST
$BRUSHDEF_END
EOF
}

sub Entity(%)
{
	my (%h) = @_;
	my @brushes = ();
	if(ref $h{model} eq 'ARRAY')
	{
		@brushes = @{$h{model}};
		delete $h{model};
	}
	return join "", ("{\n", (map { qq{"$_" "$h{$_}"\n} } keys %h), @brushes, "}\n");
	# "
}

sub FindDamage($)
{
	my ($cnt) = @_;

	my $dmg;

	# 1. divisible by 10?
	$dmg = (1 + int(10 / $cnt)) * 10;
	return $dmg
		if $dmg * ($cnt - 1) < 100;

	# 2. divisible by 5?
	$dmg = (1 + int(20 / $cnt)) * 5;
	return $dmg
		if $dmg * ($cnt - 1) < 100;

	# 3. divisible by 2?
	$dmg = (1 + int(50 / $cnt)) * 2;
	return $dmg
		if $dmg * ($cnt - 1) < 100;

	# 4. divisible by 1?
	$dmg = (1 + int(100 / $cnt));
	return $dmg
		if $dmg * ($cnt - 1) < 100;

	# 5. give up
	return (100 / $cnt + 100 / ($cnt + 1)) / 2;
}

sub ObjectiveSpawns($@)
{
	my ($target, $x, $y, $z) = @_;

	my @l = ();

	$z -= 64;

	for(1..6)
	{
		my $xx = $x - 32;
		my $yy = $y + ($_ - 3.5) * 64;
		my $zz = $z - 8 - 32; # align feet to 64-grid
		push @l, Entity
			classname => "info_player_attacker",
			target => $target,
			origin => "$xx $yy $zz";

		$xx = $x + 32;
		push @l, Entity
			classname => "info_player_defender",
			target => $target,
			origin => "$xx $yy $zz";
	}

	return @l;
}

my @assault_entities = ();

my $obj_prev = undef;
my $des_prev = undef;

my @prevorigin = @ofs;

for my $i(0..@objectives - 1)
{
	my @origin =
	(
		$ofs[0] + ($i + 1) * 256,
		$ofs[1] + 0,
		$ofs[2] + 0
	);

	my $count = $objectives[$i];
	$count =~ /^(\d+)(?:,(\d+))?$/s
		or die "Invalid count spec: must be number or number,number";
	my $count_destroy = $1;
	my $count_push = $2 || 0;
	$count = $count_destroy + $count_push;

	my $obj = "obj$i";
	my $des = "obj$i\_destructible";
	my $dec = "obj$i\_decrease";

	if($i == 0)
	{
		push @assault_entities, Entity
			classname => "target_assault_roundstart",
			target => $obj,
			target2 => $des,
			origin => "@prevorigin";
	}
	else
	{
		push @assault_entities, Entity
			classname => "target_objective",
			targetname => $obj_prev,
			target => $obj,
			target2 => $des,
			origin => "@prevorigin";

		push @assault_entities, ObjectiveSpawns $obj_prev, @prevorigin;

		push @assault_entities, Entity
			classname => "func_assault_wall",
			target => $obj_prev,
			model => [
				BrushRectangle
					"dsi/dsiglass",
					$origin[0] - 128 - 32,
					$origin[1] - 512,
					$origin[2] - 512,
					$origin[0] - 128 + 32,
					$origin[1] + 512,
					$origin[2] + 512
			];
	}

	@prevorigin = @origin;

	$origin[2] += 64;

	my $dmg = FindDamage($count);

	push @assault_entities, Entity
		classname => "target_objective_decrease",
		targetname => $dec,
		target => $obj,
		dmg => $dmg,
		origin => "@origin";

	$origin[2] += 64;

	for(1..$count_destroy)
	{
		push @assault_entities, Entity
			classname => "func_assault_destructible",
			targetname => $des,
			target => $dec,
			health => 1000,
			mdl => "rocket_explode",
			count => 1,
			noise => "weapons/rocket_impact.wav",
			dmg => 50,
			dmg_edge => 0,
			dmg_radius => 150,
			dmg_force => 200,
			model => [
				BrushRectangle
					"dsi/cretebase",
					$origin[0] - 16,
					$origin[1] - 16,
					$origin[2] - 16,
					$origin[0] + 16,
					$origin[1] + 16,
					$origin[2] + 16
			];

		$origin[2] += 64;
	}

	for(1..$count_push)
	{
		push @assault_entities, Entity
			classname => "func_button",
			target => $dec,
			angle => -2,
			model => [
				BrushRectangle
					"dsi/dablue",
					$origin[0] - 16,
					$origin[1] - 16,
					$origin[2] - 16,
					$origin[0] + 16,
					$origin[1] + 16,
					$origin[2] + 16
			];

		$origin[2] += 64;
	}

	$obj_prev = $obj;
	$des_prev = $des;
}

my $obj = "roundend";
my @origin =
(
	$ofs[0] + (@objectives + 1) * 256,
	$ofs[1] + 0,
	$ofs[2] + 0
);

push @assault_entities, Entity
	classname => "target_objective",
	targetname => $obj_prev,
	target => $obj,
	origin => "@prevorigin";

push @assault_entities, ObjectiveSpawns $obj_prev, @prevorigin;

push @assault_entities, Entity
	classname => "target_assault_roundend",
	targetname => $obj,
	origin => "@origin";

my $map = join "",
(
	Entity(classname => "worldspawn"),
	@assault_entities
);

print $map;
