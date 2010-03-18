#!/usr/bin/perl

use strict;
use warnings;
use Digest::MD5;

my $data = do { undef local $/; <STDIN>; };
my $com_token;
sub gettoken($)
{
	my ($returnnewline) = @_;
	$com_token = undef;

skipwhite:
	if($returnnewline)
	{
		$data =~ s/^[ \t]*//;
	}
	else
	{
		$data =~ s/^[ \t\r\n]*//;
	}

	return 0
		if $data eq "";

	$data =~ s/^\r\n/\n/;

	$data =~ s/^\/\/[^\r\n]*// and goto skipwhite;

	$data =~ s/^\/\*.*?\*\/// and goto skipwhite;

	if($data =~ s/^(["'])(.*?)\1//)
	{
		my $str = $1;
		my %q = ( "\\" => "\\", "n" => "\n", "t" => "\t" );
		$str =~ s/\\([\\nt])/$q{$1}/ge;
		$com_token = $str;
		return 1;
	}

	if($data =~ s/^\r//)
	{
		$com_token = "\n";
		return 1;
	}

	if($data =~ s/^([][\n{})(:,;])//)
	{
		$com_token = $1;
		return 1;
	}

	if($data =~ s/^([^][ \t\r\n{})(:,;]*)//)
	{
		$com_token = $1;
		return 1;
	}

	die "fallthrough?";
	$com_token = "";
	return 1;
}

sub normalize_path($)
{
	my ($p) = @_;
	$p =~ s/\\/\//g;
	$p =~ s/(?:\.jpg|\.png|\.tga)$//gi;
	$p = lc $p;
	return $p;
}

my $find_texture_names = grep { /^-t$/ } @ARGV;
my $dump_shaders = grep { /^-d$/ } @ARGV;
my @match = grep { !/^-/ } @ARGV;

my $shadertext;
my $curshader;

while(gettoken 0)
{
	$curshader = normalize_path $com_token;
	$shadertext = "";

	if(!gettoken(0) || $com_token ne "{")
	{
		die "parsing error - expected \"{\", found \"$com_token\"";
	}
	
	$shadertext .= "{\n";

	while(gettoken 0)
	{
		last if $com_token eq "}";

		if($com_token eq "{")
		{
			# shader layer
			# we're not actually parsing this

			$shadertext .= "	{\n";

			while(gettoken 0)
			{
				last if $com_token eq "}";
				next if $com_token eq "\n";

				my @parameter = ();

				while($com_token ne "\n" && $com_token ne "}")
				{
					push @parameter, $com_token;
					last unless gettoken 1;
				}

				$shadertext .= "		@parameter\n";

				last if $com_token eq "}";
			}

			$shadertext .= "	}\n";
		}

		my @parameter = ();

		while($com_token ne "\n" && $com_token ne "}")
		{
			push @parameter, $com_token;
			last unless gettoken 1;
		}

		next if @parameter < 1;

		$shadertext .= "	@parameter\n";
	}

	$shadertext .= "}\n";

	if(!@match || grep { $_ eq $curshader } @match)
	{
		printf "%s  %s\n", Digest::MD5::md5_hex($shadertext), $curshader;

		if($find_texture_names)
		{
			# find out possibly loaded textures
			my @maps = ($shadertext =~ /^(?:clampmap|map|q3r_lightimage|q3r_editorimage) ([^\$].*)$/gim);
			for($shadertext =~ /^animmap \S+ (.*)$/gim)
			{
				push @maps, split / /, $_;
			}
			for($shadertext =~ /^skyparms (.*)$/gim)
			{
				for(split / /, $_)
				{
					next if $_ eq "-";
					push @maps, "$_"."_lf";
					push @maps, "$_"."_ft";
					push @maps, "$_"."_rt";
					push @maps, "$_"."_bk";
					push @maps, "$_"."_up";
					push @maps, "$_"."_dn";
				}
			}
			@maps = ($curshader)
				if @maps == 0;
			printf "* %s  %s\n", $_, $curshader
				for map { normalize_path $_ } @maps;
		}

		if($dump_shaders)
		{
			print "| $_\n" for split /\n/, $shadertext;
		}
	}
}
