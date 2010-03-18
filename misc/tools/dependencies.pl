#!/usr/bin/perl

use strict;
use warnings;

my %files = ();
my %shaders = ();

sub ReadShaders()
{
	for my $sf(<scripts/*.shader>)
	{
		my $curshader = undef;
		my @tex = ();
		my $level = 0;
		open my $fh, "<", $sf
			or die "<$sf: $!";
		while(<$fh>)
		{
			s/\r//gs;
			chomp;

			s/\/\/.*//s;
			s/^\s+//;
			s/\s+$//;
			next if /^$/;

			my @line = map { s/"//g; $_; } split /\s+/, $_;

			if($line[0] eq '{')
			{
				++$level;
			}
			elsif($line[0] eq '}')
			{
				--$level;
				if($level <= 0)
				{
					$level = 0;
					if(defined $curshader)
					{
						$shaders{lc $curshader} = { shaderfile => $sf, textures => [ @tex ] };
					}
					$curshader = undef;
				}
			}
			elsif($level == 0)
			{
				$curshader = $line[0];
				@tex = ();
			}
			elsif($level == 1 and lc $line[0] eq 'qer_editorimage')
			{
				push @tex, $line[1];
			}
			elsif($level == 1 and lc $line[0] eq 'qer_lightimage')
			{
				push @tex, $line[1];
			}
			elsif($level == 1 and lc $line[0] eq 'skyparms')
			{
				for(qw/rt lf ft bk up dn/)
				{
					push @tex, "$line[1]_$_";
					push @tex, "$line[3]_$_";
				}
			}
			elsif($level == 2 and lc $line[0] eq 'map')
			{
				push @tex, $line[1];
			}
			elsif($level == 2 and lc $line[0] eq 'animmap')
			{
				for(2..(@line - 1))
				{
					push @tex, $line[$_];
				}
			}
		}
	}
}

sub AddFile($)
{
	my ($file) = @_;
	return 0
		unless -e $file;
	++$files{$file};
	return 1;
}

sub AddSound($)
{
	my ($tex) = @_;
	$tex =~ s/\.ogg$|\.wav$//i;
	AddFile "$tex.ogg" or
	AddFile "$tex.wav" or
	AddFile "sound/$tex.ogg" or
	AddFile "sound/$tex.wav";
}

sub AddTexture($)
{
	my ($tex) = @_;
	$tex =~ s/\.jpg$|\.tga$|\.png$//i;
	AddFile "$tex.jpg" or
	AddFile "$tex.tga" or
	AddFile "$tex.png"
		or return 0;
	for('_shirt', '_pants', '_glow', '_norm', '_bump', '_gloss')
	{
		AddFile "$tex$_.jpg" or
		AddFile "$tex$_.tga" or
		AddFile "$tex$_.png";
	}
	return 1;
}

sub AddShader($)
{
	my ($shader) = @_;
	$shader =~ s/\.jpg$|\.tga$|\.png$//i;
	my $si = $shaders{lc $shader};
	if(not defined $si)
	{
		AddTexture $shader
			or warn "Unknown shader used: $shader";
	}
	else
	{
		AddFile $si->{shaderfile};
		AddTexture $_
			for @{$si->{textures}};
	}
}

sub AddMapDependencies($)
{
	my ($data) = @_;
	for(/^"noise.*" "(.*)"/gm)
	{
		AddSound $1;
	}
	for(/^"sound.*" "(.*)"/gm)
	{
		AddSound $1;
	}
	for(/^"music" "(.*)"/gm)
	{
		AddSound $1;
	}
	for(/^"model" "(.*)"/gm)
	{
		# TODO make this AddModel
		# TODO and find the shaders the model uses
		AddFile $1;
	}
	for(/^"lodmodel.*" "(.*)"/gm)
	{
		AddFile $1;
	}
}

sub AddMapinfoDependencies($)
{
	my ($data) = @_;
	for($data =~ /^cdtrack (.*)$/gm)
	{
		AddSound "sound/cdtracks/$1";
	}
}

sub AddCfgDependencies($)
{
	my ($data) = @_;
	for($data =~ /^cd loop "?(.*?)"?$/gm)
	{
		AddSound "sound/cdtracks/$1";
	}
}

sub AddShaderDependencies($)
{
	my ($data) = @_;

	my $n = length($data) / 72;
	for(0..($n-1))
	{
		my $s = substr $data, $_ * 72, 64;
		$s =~ s/\0.*$//s;
		AddShader $s;
	}
}

sub AddFaceDependencies($$)
{
	my ($base, $data) = @_;

	my $n = length($data) / 104;
	for(0..($n-1))
	{
		my $l = unpack "V", substr $data, $_ * 104 + 28, 4;
		AddTexture sprintf "maps/%s/lm_%04d", $base, $l;
		AddTexture sprintf "maps/%s/lm_%04d", $base, $l | 1; # deluxe
	}
}


ReadShaders();

for(<maps/*.ent>)
{
	AddFile $_;

	my $data = do {
		undef local $/;
		open my $fh, "<", $_
			or die "<$_: $!";
		<$fh>;
	};
	AddMapDependencies $data;
}

for(<maps/*.bsp>)
{
	AddFile $_;

	m!^maps/(.*)\.bsp! or die "perl is stupid";
	my $b = $1;
	AddFile "maps/$b.mapinfo";
	AddFile "maps/$b.jpg";
	AddFile "maps/$b.cfg";
	AddFile "maps/$b.waypoints";
	AddFile "maps/$b.rtlights";
	AddTexture "gfx/$b\_radar.tga";
	AddTexture "gfx/$b\_mini.tga";

	my $data = do {
		undef local $/;
		open my $fh, "<", "maps/$b.mapinfo"
			or warn "<maps/$b.mapinfo: $!";
		<$fh>;
	};
	AddMapinfoDependencies $data;

	$data = do {
		undef local $/;
		open my $fh, "<", "maps/$b.cfg"
			or warn "<maps/$b.cfg: $!";
		<$fh>;
	};
	AddCfgDependencies $data;

	$data = do {
		undef local $/;
		open my $fh, "-|", 'bsptool.pl', $_, '-xentities'
			or die "<$_: $!";
		<$fh>;
	};
	AddMapDependencies $data;

	$data = do {
		undef local $/;
		open my $fh, "-|", 'bsptool.pl', $_, '-xfaces'
			or die "<$_: $!";
		<$fh>;
	};
	AddFaceDependencies $b, $data;

	$data = do {
		undef local $/;
		open my $fh, "-|", 'bsptool.pl', $_, '-xtextures'
			or die "<$_: $!";
		<$fh>;
	};
	AddShaderDependencies $data;
}

sub RecurseDir($);
sub RecurseDir($)
{
	my ($dir) = @_;
	if(-d $dir)
	{
		for(<$dir/*>)
		{
			RecurseDir $_;
		}
	}
	else
	{
		warn "Unused file: $dir"
			unless $files{$dir};
	}
}

for(<*>)
{
	RecurseDir $_;
}

print "$_\0"
	for sort keys %files;
