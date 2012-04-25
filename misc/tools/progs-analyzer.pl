use strict;
use warnings;

sub id()
{
	return sub { $_[0]; };
}

sub signed($)
{
	my ($bits) = @_;
	return sub { $_[0] >= (2**($bits-1)) ? $_[0]-(2**$bits) : $_[0]; };
}

use constant OPCODE_E => [qw[
	DONE
	MUL_F MUL_V MUL_FV MUL_VF
	DIV_F
	ADD_F ADD_V
	SUB_F SUB_V
	EQ_F EQ_V EQ_S EQ_E EQ_FNC
	NE_F NE_V NE_S NE_E NE_FNC
	LE GE LT GT
	LOAD_F LOAD_V LOAD_S LOAD_ENT LOAD_FLD LOAD_FNC
	ADDRESS
	STORE_F STORE_V STORE_S STORE_ENT STORE_FLD STORE_FNC
	STOREP_F STOREP_V STOREP_S STOREP_ENT STOREP_FLD STOREP_FNC
	RETURN
	NOT_F NOT_V NOT_S NOT_ENT NOT_FNC
	IF IFNOT
	CALL0 CALL1 CALL2 CALL3 CALL4 CALL5 CALL6 CALL7 CALL8
	STATE
	GOTO
	AND OR
	BITAND BITOR
]];

sub checkop($)
{
	my ($op) = @_;
	if($op =~ /^IF.*_V$/)
	{
		return { a => 'inglobalvec', b => 'immediate', isjump => 'b', isconditional => 1 };
	}
	if($op =~ /^IF/)
	{
		return { a => 'inglobal', b => 'immediate', isjump => 'b', isconditional => 1 };
	}
	if($op eq 'GOTO')
	{
		return { a => 'immediate', isjump => 'a', isconditional => 0 };
	}
	if($op =~ /^ADD_V$|^SUB_V$/)
	{
		return { a => 'inglobalvec', b => 'inglobalvec', c => 'outglobalvec' };
	}
	if($op =~ /^MUL_V$|^EQ_V$|^NE_V$/)
	{
		return { a => 'inglobalvec', b => 'inglobalvec', c => 'outglobal' };
	}
	if($op eq 'MUL_FV')
	{
		return { a => 'inglobal', b => 'inglobalvec', c => 'outglobalvec' };
	}
	if($op eq 'MUL_VF')
	{
		return { a => 'inglobalvec', b => 'inglobal', c => 'outglobalvec' };
	}
	if($op eq 'LOAD_V')
	{
		return { a => 'inglobal', b => 'inglobal', c => 'outglobalvec' };
	}
	if($op =~ /^NOT_V/)
	{
		return { a => 'inglobalvec', c => 'outglobal' };
	}
	if($op =~ /^NOT_/)
	{
		return { a => 'inglobal', c => 'outglobal' };
	}
	if($op eq 'STOREP_V')
	{
		return { a => 'inglobalvec', b => 'inglobal' };
	}
	if($op eq 'STORE_V')
	{
		return { a => 'inglobalvec', b => 'outglobalvec' };
	}
	if($op =~ /^STOREP_/)
	{
		return { a => 'inglobal', b => 'inglobal' };
	}
	if($op =~ /^STORE_/)
	{
		return { a => 'inglobal', b => 'outglobal' };
	}
	if($op =~ /^CALL/)
	{
		return { a => 'inglobalfunc', iscall => 1 };
	}
	if($op =~ /^DONE|^RETURN/)
	{
		return { a => 'inglobal', isreturn => 1 };
	}
	return { a => 'inglobal', b => 'inglobal', c => 'outglobal' };
}

use constant TYPES => {
	int => ['V', 4, signed 32],
	ushort => ['v', 2, id],
	short => ['v', 2, signed 16],
	opcode => ['v', 2, sub { OPCODE_E->[$_[0]] or die "Invalid opcode: $_[0]"; }],
	float => ['f', 4, id],
	uchar8 => ['a8', 8, sub { [unpack 'C8', $_[0]] }],
	global => ['i', 4, sub { { int => $_[0], float => unpack "f", pack "L", $_[0] }; }],
};

use constant DPROGRAMS_T => [
	[int => 'version'],
	[int => 'crc'],
	[int => 'ofs_statements'],
	[int => 'numstatements'],
	[int => 'ofs_globaldefs'],
	[int => 'numglobaldefs'],
	[int => 'ofs_fielddefs'],
	[int => 'numfielddefs'],
	[int => 'ofs_functions'],
	[int => 'numfunctions'],
	[int => 'ofs_strings'],
	[int => 'numstrings'],
	[int => 'ofs_globals'],
	[int => 'numglobals'],
	[int => 'entityfields']
];

use constant DSTATEMENT_T => [
	[opcode => 'op'],
	[short => 'a'],
	[short => 'b'],
	[short => 'c']
];

use constant DDEF_T => [
	[ushort => 'type'],
	[ushort => 'ofs'],
	[int => 's_name']
];

use constant DGLOBAL_T => [
	[global => 'v'],
];

use constant DFUNCTION_T => [
	[int => 'first_statement'],
	[int => 'parm_start'],
	[int => 'locals'],
	[int => 'profile'],
	[int => 's_name'],
	[int => 's_file'],
	[int => 'numparms'],
	[uchar8 => 'parm_size'],
];

sub get_section($$$)
{
	my ($fh, $start, $len) = @_;
	seek $fh, $start, 0
		or die "seek: $!";
	$len == read $fh, my $buf, $len
		or die "short read";
	return $buf;
}

sub parse_section($$$$$)
{
	my ($fh, $struct, $start, $len, $cnt) = @_;

	my $itemlen = 0;
	$itemlen += TYPES->{$_->[0]}->[1]
		for @$struct;
	my $packspec = join '', map { TYPES->{$_->[0]}->[0]; } @$struct;
	my @packnames = map { $_->[1]; } @$struct;

	$len = $cnt * $itemlen
		if not defined $len and defined $cnt;
	$cnt = int($len / $itemlen)
		if not defined $cnt and defined $len;
	die "Invalid length specification"
		unless defined $len and defined $cnt and $len == $cnt * $itemlen;
	die "Invalid length specification in scalar context"
		unless wantarray or $cnt == 1;

	seek $fh, $start, 0
		or die "seek: $!";
	my @out = map
	{
		$itemlen == read $fh, my $buf, $itemlen
			or die "short read";
		my %h = ();
		@h{@packnames} = unpack $packspec, $buf;
		$h{$_->[1]} = TYPES->{$_->[0]}->[2]->($h{$_->[1]})
			for @$struct;
		\%h;
	}
	0..($cnt-1);
	return @out
		if wantarray;
	return $out[0];
}

use constant PRE_MARK_STATEMENT => "\e[1m";
use constant POST_MARK_STATEMENT => "\e[m";
use constant PRE_MARK_OPERAND => "\e[41m";
use constant POST_MARK_OPERAND => "\e[49m";

use constant INSTRUCTION_FORMAT => "%8s %3s | %-12s ";
use constant OPERAND_FORMAT => "%s";
use constant OPERAND_SEPARATOR => ", ";
use constant INSTRUCTION_SEPARATOR => "\n";

sub str($)
{
	my ($str) = @_;
	$str =~ s/[\000-\037\\\"\177-\377]/sprintf "\\%03o", ord $&/ge;
	return "\"$str\"";
}

sub disassemble_function($$;$)
{
	my ($progs, $func, $highlight) = @_;

	print "$func->{debugname}:\n";

	my $initializer = sub
	{
		my ($ofs) = @_;
		my $g = $progs->{globals}[$ofs]{v};
		if($g->{int} == 0)
		{
		}
		elsif($g->{int} < 16777216)
		{
			print " = $g->{int}%";
			if($g->{int} < length $progs->{strings} && $g->{int} > 0)
			{
				print " " . str($progs->{getstring}->($g->{int}));
			}
		}
		else
		{
			print " = $g->{float}!";
		}
	};

	printf INSTRUCTION_FORMAT, '', '', '.PARM_START';
	printf OPERAND_FORMAT, "$func->{parm_start}";
	print INSTRUCTION_SEPARATOR;

	printf INSTRUCTION_FORMAT, '', '', '.LOCALS';
	printf OPERAND_FORMAT, "$func->{locals}";
	print INSTRUCTION_SEPARATOR;

	my %override_locals = ();
	my $p = $func->{parm_start};
	for(0..($func->{numparms}-1))
	{
		if($func->{parm_size}[$_] <= 1)
		{
			$override_locals{$p} //= "argv[$_]";
		}
		for my $comp(0..($func->{parm_size}[$_]-1))
		{
			$override_locals{$p} //= "argv[$_][$comp]";
			++$p;
		}
		printf INSTRUCTION_FORMAT, '', '', '.ARG';
		printf OPERAND_FORMAT, "argv[$_]";
		print OPERAND_SEPARATOR;
		printf OPERAND_FORMAT, $func->{parm_size}[$_];
		print INSTRUCTION_SEPARATOR;
	}
	for($func->{parm_start}..($func->{parm_start} + $func->{locals} - 1))
	{
		next
			if exists $override_locals{$_};
		$override_locals{$_} = "<local>\@$_";

		printf INSTRUCTION_FORMAT, '', '', '.LOCAL';
		printf OPERAND_FORMAT, "<local>\@$_";
		$initializer->($_);
		print INSTRUCTION_SEPARATOR;
	}

	my $getname = sub
	{
		my ($ofs) = @_;
		return $override_locals{$ofs}
			if exists $override_locals{$ofs};
		return $progs->{globaldef_byoffset}->($ofs)->{debugname};
	};

	my $operand = sub
	{
		my ($type, $operand) = @_;
		if($type eq 'inglobal')
		{
			my $name = $getname->($operand);
			printf OPERAND_FORMAT, "$name";
		}
		elsif($type eq 'outglobal')
		{
			my $name = $getname->($operand);
			printf OPERAND_FORMAT, "&$name";
		}
		elsif($type eq 'inglobalvec')
		{
			my $name = $getname->($operand);
			printf OPERAND_FORMAT, "$name\[\]";
		}
		elsif($type eq 'outglobalvec')
		{
			my $name = $getname->($operand);
			printf OPERAND_FORMAT, "&$name\[\]";
		}
		elsif($type eq 'inglobalfunc')
		{
			my $name = $getname->($operand);
			printf OPERAND_FORMAT, "$name()";
		}
		elsif($type eq 'immediate')
		{
			printf OPERAND_FORMAT, "$operand";
		}
		else
		{
			die "unknown type: $type";
		}
	};

	for my $s($func->{first_statement}..(@{$progs->{statements}}-1))
	{
		my $op = $progs->{statements}[$s]{op};
		my $st = $progs->{statements}[$s];
		my $opprop = checkop $op;

		print PRE_MARK_STATEMENT
			if $highlight and $highlight->{$s};

		printf INSTRUCTION_FORMAT, $s, $highlight->{$s} ? "<!>" : "", $op;

		my $cnt = 0;
		for my $o(qw(a b c))
		{
			next
				if not defined $opprop->{$o};
			print OPERAND_SEPARATOR
				if $cnt++;
			print PRE_MARK_OPERAND
				if $highlight and $highlight->{$s} and $highlight->{$s}{$o};
			$operand->($opprop->{$o}, $st->{$o});
			print POST_MARK_OPERAND
				if $highlight and $highlight->{$s} and $highlight->{$s}{$o};
		}

		print POST_MARK_STATEMENT
			if $highlight and $highlight->{$s};

		print INSTRUCTION_SEPARATOR;

		last if $progs->{function_byoffset}->($s + 1);
	}
}

sub find_uninitialized_locals($$)
{
	my ($progs, $func) = @_;

	no warnings 'recursion';

	my %warned = ();

	my %instructions_seen;
	my $checkinstruction;
	$checkinstruction = sub
	{
		my ($ip, $watchlist) = @_;
		for(;;)
		{
			my $statestr = join ' ', map { $watchlist->{$_}->{valid}; } sort keys %$watchlist;
			return
				if $instructions_seen{"$ip $statestr"}++;
			my %s = %{$progs->{statements}[$ip]};
			my %c = %{checkop $s{op}};
			for(qw(a b c))
			{
				my $x = $s{$_};
				if(!defined $c{$_})
				{
				}
				elsif($c{$_} eq 'inglobal' || $c{$_} eq 'inglobalfunc')
				{
					if($s{op} ne 'OR' && $s{op} ne 'AND') # fteqcc logicops cause this
					{
						if($watchlist->{$x} && !$watchlist->{$x}{valid})
						{
							print "; Use of uninitialized local $x in $func->{debugname} at $ip.$_\n";
							++$warned{$ip}{$_};
						}
					}
				}
				elsif($c{$_} eq 'inglobalvec')
				{
					if($s{op} ne 'OR' && $s{op} ne 'AND') # fteqcc logicops cause this
					{
						if(
						   $watchlist->{$x} && !$watchlist->{$x}{valid}
								||
						   $watchlist->{$x+1} && !$watchlist->{$x+1}{valid}
								||
						   $watchlist->{$x+2} && !$watchlist->{$x+2}{valid}
						)
						{
							print "; Use of uninitialized local $x in $func->{debugname} at $ip.$_\n";
							++$warned{$ip}{$_};
						}
					}
				}
				elsif($c{$_} eq 'outglobal')
				{
					$watchlist->{$x}{valid} = 1
						if $watchlist->{$x};
				}
				elsif($c{$_} eq 'outglobalvec')
				{
					$watchlist->{$x}{valid} = 1
						if $watchlist->{$x};
					$watchlist->{$x+1}{valid} = 1
						if $watchlist->{$x+1};
					$watchlist->{$x+2}{valid} = 1
						if $watchlist->{$x+2};
				}
				elsif($c{$_} eq 'immediate')
				{
					# OK
				}
			}
			if($c{isreturn})
			{
				last;
			}
			elsif($c{isjump})
			{
				if($c{isconditional})
				{
					$checkinstruction->($ip+1, { map { $_ => { %{$watchlist->{$_}} } } keys %$watchlist });
					$ip += $s{$c{isjump}};
				}
				else
				{
					$ip += $s{$c{isjump}};
				}
			}
			else
			{
				$ip += 1;
			}
		}
	};
	
	return
		if $func->{first_statement} < 0; # builtin


	print STDERR "Checking $func->{debugname}...\n";

	my $p = $func->{parm_start};
	for(0..($func->{numparms}-1))
	{
		$p += $func->{parm_size}[$_];
	}

	use constant WATCHME_R => 1;
	use constant WATCHME_W => 2;
	use constant WATCHME_X => 4;
	use constant WATCHME_T => 8;
	my %watchme = map { $_ => WATCHME_X } ($p .. ($func->{parm_start} + $func->{locals} - 1));
	# TODO mark temp globals as WATCHME_T

	my $fixinitialstate;
       	$fixinitialstate = sub
	{
		my ($ip) = @_;
		for(;;)
		{
			return
				if $instructions_seen{$ip}++;
			my %s = %{$progs->{statements}[$ip]};
			my %c = %{checkop $s{op}};
			for(qw(a b c))
			{
				if(!defined $c{$_})
				{
				}
				elsif($c{$_} eq 'inglobal' || $c{$_} eq 'inglobalfunc')
				{
					$watchme{$s{$_}} |= WATCHME_R;
				}
				elsif($c{$_} eq 'inglobalvec')
				{
					$watchme{$s{$_}} |= WATCHME_R;
					$watchme{$s{$_}+1} |= WATCHME_R;
					$watchme{$s{$_}+2} |= WATCHME_R;
				}
				elsif($c{$_} eq 'outglobal')
				{
					$watchme{$s{$_}} |= WATCHME_W;
				}
				elsif($c{$_} eq 'outglobalvec')
				{
					$watchme{$s{$_}} |= WATCHME_W;
					$watchme{$s{$_}+1} |= WATCHME_W;
					$watchme{$s{$_}+2} |= WATCHME_W;
				}
				elsif($c{$_} eq 'immediate')
				{
					# OK
				}
			}
			if($c{isreturn})
			{
				last;
			}
			elsif($c{isjump})
			{
				if($c{isconditional})
				{
					$fixinitialstate->($ip+1);
					$ip += $s{$c{isjump}};
				}
				else
				{
					$ip += $s{$c{isjump}};
				}
			}
			else
			{
				$ip += 1;
			}
		}
	};
	%instructions_seen = ();
	$fixinitialstate->($func->{first_statement});

	for(keys %watchme)
	{
		delete $watchme{$_}
			if
				($watchme{$_} & (WATCHME_T | WATCHME_X)) == 0
					or
				($watchme{$_} & (WATCHME_R | WATCHME_W)) != (WATCHME_R | WATCHME_W);
	}

	return
		if not keys %watchme;

	for(keys %watchme)
	{
		$watchme{$_} = { flags => $watchme{$_}, valid => 0 };
	}

	%instructions_seen = ();
	$checkinstruction->($func->{first_statement}, \%watchme);
	disassemble_function($progs, $func, \%warned)
		if keys %warned;
}

use constant DEFAULTGLOBALS => [
	"<OFS_NULL>",
	"<OFS_RETURN>",
	"<OFS_RETURN>[1]",
	"<OFS_RETURN>[2]",
	"<OFS_PARM0>",
	"<OFS_PARM0>[1]",
	"<OFS_PARM0>[2]",
	"<OFS_PARM1>",
	"<OFS_PARM1>[1]",
	"<OFS_PARM1>[2]",
	"<OFS_PARM2>",
	"<OFS_PARM2>[1]",
	"<OFS_PARM2>[2]",
	"<OFS_PARM3>",
	"<OFS_PARM3>[1]",
	"<OFS_PARM3>[2]",
	"<OFS_PARM4>",
	"<OFS_PARM4>[1]",
	"<OFS_PARM4>[2]",
	"<OFS_PARM5>",
	"<OFS_PARM5>[1]",
	"<OFS_PARM5>[2]",
	"<OFS_PARM6>",
	"<OFS_PARM6>[1]",
	"<OFS_PARM6>[2]",
	"<OFS_PARM7>",
	"<OFS_PARM7>[1]",
	"<OFS_PARM7>[2]"
];

sub defaultglobal($)
{
	my ($ofs) = @_;
	if($ofs < @{(DEFAULTGLOBALS)})
	{
		return { ofs => $ofs, s_name => undef, debugname => DEFAULTGLOBALS->[$ofs], type => undef };
	}
	return { ofs => $ofs, s_name => undef, debugname => "<undefined>\@$ofs", type => undef };
}

sub parse_progs($)
{
	my ($fh) = @_;

	my %p = ();

	print STDERR "Parsing header...\n";
	$p{header} = parse_section $fh, DPROGRAMS_T, 0, undef, 1;
	
	print STDERR "Parsing strings...\n";
	$p{strings} = get_section $fh, $p{header}{ofs_strings}, $p{header}{numstrings};

	print STDERR "Parsing statements...\n";
	$p{statements} = [parse_section $fh, DSTATEMENT_T, $p{header}{ofs_statements}, undef, $p{header}{numstatements}];

	print STDERR "Parsing globaldefs...\n";
	$p{globaldefs} = [parse_section $fh, DDEF_T, $p{header}{ofs_globaldefs}, undef, $p{header}{numglobaldefs}];

	print STDERR "Parsing fielddefs...\n";
	$p{fielddefs} = [parse_section $fh, DDEF_T, $p{header}{ofs_fielddefs}, undef, $p{header}{numfielddefs}];

	print STDERR "Parsing globals...\n";
	$p{globals} = [parse_section $fh, DGLOBAL_T, $p{header}{ofs_globals}, undef, $p{header}{numglobals}];

	print STDERR "Parsing functions...\n";
	$p{functions} = [parse_section $fh, DFUNCTION_T, $p{header}{ofs_functions}, undef, $p{header}{numfunctions}];

	print STDERR "Providing helpers...\n";
	$p{getstring} = sub
	{
		my ($startpos) = @_;
		my $endpos = index $p{strings}, "\0", $startpos;
		return substr $p{strings}, $startpos, $endpos - $startpos;
	};

	print STDERR "Naming...\n";

	# globaldefs
	my @globaldefs = ();
	for(@{$p{globaldefs}})
	{
		$_->{debugname} = $p{getstring}->($_->{s_name});
	}
	for(@{$p{globaldefs}})
	{
		next
			unless $_->{debugname};
		if(!defined $globaldefs[$_->{ofs}] || length $globaldefs[$_->{ofs}]->{debugname} < length $_->{debugname})
		{
			$globaldefs[$_->{ofs}] = $_;
		}
	}
	my %globaldefs = ();
	for(@{$p{globaldefs}})
	{
		$_->{debugname} = "<anon>\@$_->{ofs}"
			if $_->{debugname} eq "";
		++$globaldefs{$_->{debugname}};
	}
	for(@{$p{globaldefs}})
	{
		next
			if $globaldefs{$_->{debugname}} <= 1;
		$_->{debugname} .= "\@$_->{ofs}";
	}
	$p{globaldef_byoffset} = sub
	{
		my ($ofs) = @_;
		my $def = $globaldefs[$ofs]
			or return defaultglobal $_[0];
	};

	# functions
	my %functions = ();
	for(@{$p{functions}})
	{
		my $file = $p{getstring}->($_->{s_file});
		my $name = $p{getstring}->($_->{s_name});
		$name = "$file:$name"
			if length $file;
		$_->{debugname} = $name;
		$functions{$_->{first_statement}} = $_;
	}
	$p{function_byoffset} = sub
	{
		my ($ofs) = @_;
		return $functions{$ofs};
	};

	# what do we want to do?
	my $checkfunc = \&find_uninitialized_locals;
	for(sort { $a->{debugname} <=> $b->{debugname} } @{$p{functions}})
	{
		$checkfunc->(\%p, $_);
	}
}

open my $fh, '<', $ARGV[0];
parse_progs $fh;
