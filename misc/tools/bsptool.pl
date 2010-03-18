#!/usr/bin/perl

use strict;
use warnings;
use Image::Magick;
use POSIX qw/floor ceil/;

my @lumpname = qw/entities textures planes nodes leafs leaffaces leafbrushes models brushes brushsides vertices triangles effects faces lightmaps lightgrid pvs advertisements/;
my %lumpid = map { $lumpname[$_] => $_ } 0..@lumpname-1;
my $msg = "";
my @bsp;

# READ THE BSP

if(!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help')
{
	print <<EOF;
Usage:
  $0 filename.bsp [operations...]

Operations are:
  Information requests:
    -i                print info about the BSP file
    -xlumpname        extract a lump (see -i)

  Changes:
    -dlumpname        delete a lump (see -i)
    -rlumpname        replace a lump (see -i) by the data from standard input
    -gfilename.tga    save the lightgrid as filename.tga (debugging)
    -Gratio           scale down the lightgrid to reduce BSP file size
    -ljpgNNN          externalize the lightmaps as JPEG, quality NNN (number from 1 to 100)
    -lpng             externalize the lightmaps as PNG
    -ltga             externalize the lightmaps as TGA
    -mMESSAGE         set the BSP file comment message

  Save commands:
    -o                actually apply the changes to the BSP
    -ofilename2.bsp   save the changes to a new BSP file
EOF
	exit;
}

my $fn = shift @ARGV;
$fn =~ /(.*)\.bsp$/
	or die "invalid input file name (must be a .bsp): $fn";
my $basename = $1;
open my $fh, "<", $fn
	or die "$fn: $!";

read $fh, my $header, 8;

die "Invalid BSP format"
	if $header ne "IBSP\x2e\x00\x00\x00";

for(0..16)
{
	read $fh, my $lump, 8;
	my ($offset, $length) = unpack "VV", $lump;

	push @bsp, [$offset, $length, undef];
}

for(@bsp)
{
	my ($offset, $length, $data) = @$_;
	seek $fh, $offset, 0;
	read $fh, $data, $length;
	length $data == $length
		or die "Incomplete BSP lump at $offset\n";
	$_->[2] = $data;
}

close $fh;

# STRUCT DECODING

sub DecodeLump($@)
{
	my ($lump, @fields) = @_;
	my @decoded;

	my $spec = "";
	my @decoders;

	my $item;
	my @data;
	my $idx;

	for(@fields)
	{
		if(/^(\w*)=(.*?)(\d*)$/)
		{
			$spec .= "$2$3 ";
			my $f = $1;
			my $n = $3;
			if($n eq '')
			{
				push @decoders, sub { $item->{$f} = $data[$idx++]; };
			}
			else
			{
				push @decoders, sub { $item->{$f} = [ map { $data[$idx++] } 1..$n ]; };
			}
		}
	}

	my $itemlen = length pack $spec, ();
	my $len = length $lump;

	die "Invalid lump size: $len not divisible by $itemlen"
		if $len % $itemlen;

	my $items = $len / $itemlen;
	for(0..$items - 1)
	{
		@data = unpack $spec, substr $lump, $_ * $itemlen, $itemlen;
		$item = {};
		$idx = 0;
		$_->() for @decoders;
		push @decoded, $item;
	}
	@decoded;
}

sub EncodeLump($@)
{
	my ($items, @fields) = @_;
	my @decoded;

	my @encoders;

	my $item;
	my @data;
	my $idx;
	my $data = "";

	for(@fields)
	{
		if(/^(\w*)=(.*?)(\d*)$/)
		{
			my $spec = "$2$3";
			my $f = $1;
			my $n = $3;
			if($n eq '')
			{
				push @encoders, sub { $data .= pack $spec, $item->{$f}; };
			}
			else
			{
				push @encoders, sub { $data .= pack $spec, @{$item->{$f}}; };
			}
		}
	}

	for my $i(@$items)
	{
		$item = $i;
		$_->() for @encoders;
	}

	$data;
}

sub EncodeDirection(@)
{
	my ($x, $y, $z) = @_;

	return [
		map { ($_ / 0.02454369260617025967) & 0xFF }
		(
			atan2(sqrt($x * $x + $y * $y), $z),
			atan2($y, $x)
		)
	];
}

sub DecodeDirection($)
{
	my ($dir) = @_;

	my ($pitch, $yaw) = map { $_ * 0.02454369260617025967 } @$dir; # maps 256 to 2pi

	return (
		cos($yaw) * sin($pitch),
		sin($yaw) * sin($pitch),
		cos($pitch)
	);
}

sub IntervalIntersection($$$$)
{
	my ($a, $al, $b, $bl) = @_;
	my $a0 = $a - 0.5 * $al;
	my $a1 = $a + 0.5 * $al;
	my $b0 = $b - 0.5 * $bl;
	my $b1 = $b + 0.5 * $bl;
	my $left = ($a0 > $b0) ? $a0 : $b0;
	my $right = ($a1 > $b1) ? $b1 : $a1;
	die "Non-intersecting intervals $a $al $b $bl"
		if $right < $left;
	return $right - $left;
}

sub BoxIntersection(@)
{
	my ($x, $y, $z, $w, $h, $d, $x2, $y2, $z2, $w2, $h2, $d2) = @_;
	return
		IntervalIntersection($x, $w, $x2, $w2)
		*
		IntervalIntersection($y, $h, $y2, $h2)
		*
		IntervalIntersection($z, $d, $z2, $d2);
}

# OPTIONS

for(@ARGV)
{
	if(/^-i$/) # info
	{
		my $total = 17 * 8 + 8 + length($msg);
		my $max = 0;
		for(0..@bsp-1)
		{
			my $nl = length $bsp[$_]->[2];
			$total += $nl;
			print "BSP lump $_ ($lumpname[$_]): offset $bsp[$_]->[0] length $bsp[$_]->[1] newlength $nl\n";
			my $endpos = $bsp[$_]->[0] + $bsp[$_]->[1];
			$max = $endpos if $max < $endpos;
		}
		print "BSP file size will change from $max to $total bytes\n";
	}
	elsif(/^-d(.+)$/) # delete a lump
	{
		my $id = $lumpid{$1};
		die "invalid lump $1 to remove"
			unless defined $id;
		$bsp[$id]->[2] = "";
	}
	elsif(/^-r(.+)$/) # replace a lump
	{
		my $id = $lumpid{$1};
		die "invalid lump $1 to replace"
			unless defined $id;
		$bsp[$id]->[2] = do { undef local $/; scalar <STDIN>; };
	}
	elsif(/^-m(.*)$/) # change the message
	{
		$msg = $1;
	}
	elsif(/^-l(jpg|png|tga)(\d+)?$/) # externalize lightmaps (deleting the internal ones)
	{
		my $ext = $1;
		my $quality = $2;
		my %lightmaps = ();
		my $faces = $bsp[$lumpid{faces}]->[2];
		my $lightmaps = $bsp[$lumpid{lightmaps}]->[2];
		my @values = DecodeLump $faces,
			qw/texture=V effect=V type=V vertex=V n_vertexes=V meshvert=V n_meshverts=V lm_index=V lm_start=f2 lm_size=f2 lm_origin=f3 lm_vec_0=f3 lm_vec_1=f3 normal=f3 size=V2/;
		my $oddfound = 0;
		for(@values)
		{
			my $l = $_->{lm_index};
			next if $l >= 2**31; # signed
			$oddfound = 1
				if $l % 2;
			++$lightmaps{$l};
		}
		if(!$oddfound)
		{
			$lightmaps{$_+1} = $lightmaps{$_} for keys %lightmaps;
		}
		for(sort { $a <=> $b } keys %lightmaps)
		{
			print STDERR "Lightmap $_ was used $lightmaps{$_} times\n";

			# export that lightmap
			my $lmsize = 128 * 128 * 3;
			next if length $lightmaps < ($_ + 1) * $lmsize;
			my $lmdata = substr $lightmaps, $_ * $lmsize, $lmsize;
			my $img = Image::Magick->new(size => '128x128', depth => 8, magick => 'RGB');
			$img->BlobToImage($lmdata);
			my $outfn = sprintf "%s/lm_%04d.$ext", $basename, $_;
			mkdir $basename;
			$img->Set(quality => $quality)
				if defined $quality;
			my $err = $img->Write($outfn);
			die $err
				if $err;
			print STDERR "Wrote $outfn\n";
		}

		# nullify the lightmap lump
		$bsp[$lumpid{lightmaps}]->[2] = "";
	}
	elsif(/^-g(.+)$/) # export light grid as an image (for debugging)
	{
		my $filename = $1;
		my @models = DecodeLump $bsp[$lumpid{models}]->[2],
			qw/mins=f3 maxs=f3 face=V n_faces=V brush=V n_brushes=V/;
		my $entities = $bsp[$lumpid{entities}]->[2];
		my @entitylines = split /\r?\n/, $entities;
		my $gridsize = "64 64 128";
		for(@entitylines)
		{
			last if $_ eq '}';
			/^\s*"_?gridsize"\s+"(.*)"$/
				and $gridsize = $1;
		}
		my @scale = map { 1 / $_ } split / /, $gridsize;
		my @imins = map { ceil($models[0]{mins}[$_] * $scale[$_]) } 0..2;
		my @imaxs = map { floor($models[0]{maxs}[$_] * $scale[$_]) } 0..2;
		my @isize = map { $imaxs[$_] - $imins[$_] + 1 } 0..2;
		my $isize = $isize[0] * $isize[1] * $isize[2];
		my @gridcells = DecodeLump $bsp[$lumpid{lightgrid}]->[2],
			qw/ambient=C3 directional=C3 dir=C2/;
		die "Cannot decode light grid"
			unless $isize == @gridcells;

		# sum up the "ambient" light over all pixels
		my @pixels;
		my $max = 1;
		for my $y(0..$isize[1]-1)
		{
			for my $x(0..$isize[0]-1)
			{
				my ($r, $g, $b) = (0, 0, 0);
				for my $z(0..$isize[2]-1)
				{
					my $cell = $gridcells[$x + $y * $isize[0] + $z * $isize[0] * $isize[1]];
					$r += $cell->{ambient}->[0];
					$g += $cell->{ambient}->[1];
					$b += $cell->{ambient}->[2];
				}
				push @pixels, [$r, $g, $b];
				$max = $r if $max < $r;
				$max = $g if $max < $g;
				$max = $b if $max < $b;
			}
		}
		my $pixeldata = "";
		for my $p(@pixels)
		{
			$pixeldata .= pack "CCC", map { 255 * $p->[$_] / $max } 0..2;
		}

		my $img = Image::Magick->new(size => sprintf("%dx%d", $isize[0], $isize[1]), depth => 8, magick => 'RGB');
		$img->BlobToImage($pixeldata);
		$img->Write($filename);
		print STDERR "Wrote $filename\n";
	}
	elsif(/^-G(.+)$/) # decimate light grid
	{
		my $decimate = $1;
		my $filter = 1; # 0 = nearest, 1 = box filter

		my @models = DecodeLump $bsp[$lumpid{models}]->[2],
			qw/mins=f3 maxs=f3 face=V n_faces=V brush=V n_brushes=V/;
		my $entities = $bsp[$lumpid{entities}]->[2];
		my @entitylines = split /\r?\n/, $entities;
		my $gridsize = "64 64 128";
		my $gridsizeindex = undef;
		for(0..@entitylines-1)
		{
			my $l = $entitylines[$_];
			last if $l eq '}';
			if($l =~ /^\s*"_?gridsize"\s+"(.*)"$/)
			{
				$gridsize = $1;
				$gridsizeindex = $_;
			}
		}
		my @scale = map { 1 / $_ } split / /, $gridsize;
		my @imins = map { ceil($models[0]{mins}[$_] * $scale[$_]) } 0..2;
		my @imaxs = map { floor($models[0]{maxs}[$_] * $scale[$_]) } 0..2;
		my @isize = map { $imaxs[$_] - $imins[$_] + 1 } 0..2;
		my $isize = $isize[0] * $isize[1] * $isize[2];
		my @gridcells = DecodeLump $bsp[$lumpid{lightgrid}]->[2],
			qw/ambient=C3 directional=C3 dir=C2/;
		die "Cannot decode light grid"
			unless $isize == @gridcells;

		# get the new grid size values
		my @newscale = map { $_ / $decimate } @scale;
		my $newgridsize = join " ", map { 1 / $_ } @newscale;
		my @newimins = map { ceil($models[0]{mins}[$_] * $newscale[$_]) } 0..2;
		my @newimaxs = map { floor($models[0]{maxs}[$_] * $newscale[$_]) } 0..2;
		my @newisize = map { $newimaxs[$_] - $newimins[$_] + 1 } 0..2;

		# do the decimation
		my @newgridcells = ();
		for my $z($newimins[2]..$newimaxs[2])
		{
			# the coords are MIDPOINTS of the grid cells!
			my @oldz = grep { $_ >= $imins[2] && $_ <= $imaxs[2] } floor(($z - 0.5) * $decimate + 0.5) .. ceil(($z + 0.5) * $decimate - 0.5);
			my $innerz_raw = $z * $decimate;
			my $innerz = floor($innerz_raw + 0.5);
			$innerz = $imins[2] if $innerz < $imins[2];
			$innerz = $imaxs[2] if $innerz > $imaxs[2];
			for my $y($newimins[1]..$newimaxs[1])
			{
				my @oldy = grep { $_ >= $imins[1] && $_ <= $imaxs[1] } floor(($y - 0.5) * $decimate + 0.5) .. ceil(($y + 0.5) * $decimate - 0.5);
				my $innery_raw = $y * $decimate;
				my $innery = floor($innery_raw + 0.5);
				$innery = $imins[1] if $innery < $imins[1];
				$innery = $imaxs[1] if $innery > $imaxs[1];
				for my $x($newimins[0]..$newimaxs[0])
				{
					my @oldx = grep { $_ >= $imins[0] && $_ <= $imaxs[0] } floor(($x - 0.5) * $decimate + 0.5) .. ceil(($x + 0.5) * $decimate - 0.5);
					my $innerx_raw = $x * $decimate;
					my $innerx = floor($innerx_raw + 0.5);
					$innerx = $imins[0] if $innerx < $imins[0];
					$innerx = $imaxs[0] if $innerx > $imaxs[0];

					my @vec = (0, 0, 0);
					my @dir = (0, 0, 0);
					my @amb = (0, 0, 0);
					my $weight = 0;
					my $innercell = $gridcells[($innerx - $imins[0]) + $isize[0] * ($innery - $imins[1]) + $isize[0] * $isize[1] * ($innerz - $imins[2])];
					for my $Z(@oldz)
					{
						for my $Y(@oldy)
						{
							for my $X(@oldx)
							{
								my $cell = $gridcells[($X - $imins[0]) + $isize[0] * ($Y - $imins[1]) + $isize[0] * $isize[1] * ($Z - $imins[2])];

								my $cellweight = BoxIntersection(
									$X, $Y, $Z, 1, 1, 1,
									map { $_ * $decimate } $x, $y, $z, 1, 1, 1
								);

								$dir[$_] += $cellweight * $cell->{directional}->[$_] for 0..2;
								$amb[$_] += $cellweight * $cell->{ambient}->[$_] for 0..2;
								my @norm = DecodeDirection $cell->{dir};
								$vec[$_] += $cellweight * $norm[$_] for 0..2;
								$weight += $cellweight;
							}
						}
					}
					if($weight)
					{
						$dir[$_] /= $weight for 0..2;
						$dir[$_] *= $filter for 0..2;
						$dir[$_] += (1 - $filter) * $innercell->{directional}->[$_] for 0..2;

						$amb[$_] /= $weight for 0..2;
						$amb[$_] *= $filter for 0..2;
						$amb[$_] += (1 - $filter) * $innercell->{ambient}->[$_] for 0..2;

						my @norm = DecodeDirection $innercell->{dir};
						$vec[$_] /= $weight for 0..2;
						$vec[$_] *= $filter for 0..2;
						$vec[$_] += (1 - $filter) * $norm[$_] for 0..2;

						$innercell = {
							ambient => \@amb,
							directional => \@dir,
							dir => EncodeDirection @norm
						};
					}

					push @newgridcells, $innercell;
				}
			}
		}

		$bsp[$lumpid{lightgrid}]->[2] = EncodeLump \@newgridcells,
			qw/ambient=C3 directional=C3 dir=C2/;
		splice @entitylines, $gridsizeindex, 1, ()
			if defined $gridsizeindex;
		splice @entitylines, 1, 0, qq{"gridsize" "$newgridsize"};
		$bsp[$lumpid{entities}]->[2] = join "\n", @entitylines;
	}
	elsif(/^-x(.+)$/) # extract lump to stdout
	{
		my $id = $lumpid{$1};
		die "invalid lump $1 to extract"
			unless defined $id;
		print $bsp[$id]->[2];
	}
	elsif(/^-o(.+)?$/) # write the final BSP file
	{
		my $outfile = $1;
		$outfile = $fn
			if not defined $outfile;
		open my $fh, ">", $outfile
			or die "$outfile: $!";
		print $fh $header;
		my $pos = 17 * 8 + tell($fh) + length $msg;
		for(@bsp)
		{
			$_->[0] = $pos;
			$_->[1] = length $_->[2];
			$pos += $_->[1];
			print $fh pack "VV", $_->[0], $_->[1];
		}
		print $fh $msg;
		for(@bsp)
		{
			print $fh $_->[2];
		}
		close $fh;
		print STDERR "Wrote $outfile\n";
	}
	else
	{
		die "Invalid option: $_";
	}
}

# TODO:
#   features like:
#     decimate light grid
#     edit lightmaps/grid
