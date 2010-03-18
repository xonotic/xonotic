#!/usr/bin/perl

for(@ARGV)
{
	my $data = do {
		open my $fh, "<", $_;
		undef local $/;
		<$fh>;
	};

	my $vertex = undef;
	my $poly = undef;
	my $type = undef;

	if("IDP3" eq substr $data, 0, 4)
	{
		# MD3 model
		my $num_meshes = unpack "V", substr $data, 4+4+64+4+4+4, 4;
		my $ofs_meshes = unpack "V", substr $data, 4+4+64+4+4+4+4+4+4+4, 4;
		$vertex = $poly = 0;
		for(1..$num_meshes)
		{
			$vertex     += unpack "V", substr $data, $ofs_meshes+4+64+4+4+4, 4;
			$poly       += unpack "V", substr $data, $ofs_meshes+4+64+4+4+4+4, 4;
			$ofs_meshes += unpack "V", substr $data, $ofs_meshes+4+64+4+4+4+4+4+4+4+4+4, 4;
		}
		$type = "md3";
	}
	elsif("ZYMOTICMODEL" eq substr $data, 0, 12)
	{
		# ZYM model
		$vertex = unpack "N", substr $data, 12+4+4+4*3+4*3+4, 4;
		$poly   = unpack "N", substr $data, 12+4+4+4*3+4*3+4+4, 4;
		$type = "zym";
	}

	if(defined $type)
	{
		printf "%8d %8d %-3s %s\n", $vertex, $poly, $type, $_;
	}
	else
	{
		printf "%8s %8s %-3s %s\n", "-", "-", "-", $_;
	}
}
