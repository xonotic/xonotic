#!/usr/bin/perl

use strict;
use warnings;
use Digest::SHA;
use Carp;

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
use constant ETYPE_E => [qw[
	void
	string
	float
	vector
	entity
	field
	function
	pointer
]];
use constant DEF_SAVEGLOBAL => 32768;
sub typesize($)
{
	my ($type) = @_;
	return 3 if $type eq 'vector';
	return 1;
}

sub checkop($)
{
	my ($op) = @_;
	if($op =~ /^IF.*_V$/)
	{
		return { a => 'inglobalvec', b => 'ipoffset', isjump => 'b', isconditional => 1 };
	}
	if($op =~ /^IF/)
	{
		return { a => 'inglobal', b => 'ipoffset', isjump => 'b', isconditional => 1 };
	}
	if($op eq 'GOTO')
	{
		return { a => 'ipoffset', isjump => 'a', isconditional => 0 };
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
	if($op =~ /^DONE$|^RETURN$/)
	{
		return { a => 'inglobalvec', isreturn => 1 };
	}
	if($op eq 'STATE')
	{
		return { a => 'inglobal', b => 'inglobalfunc' };
	}
	if($op =~ /^INVALID#/)
	{
		return { isinvalid => 1 };
	}
	return { a => 'inglobal', b => 'inglobal', c => 'outglobal' };
}

use constant TYPES => {
	int => ['V', 4, signed 32],
	ushort => ['v', 2, id],
	short => ['v', 2, signed 16],
	opcode => ['v', 2, sub { OPCODE_E->[$_[0]] or do { warn "Invalid opcode: $_[0]"; "INVALID#$_[0]"; }; }],
	float => ['f', 4, id],
	uchar8 => ['a8', 8, sub { [unpack 'C8', $_[0]] }],
	global => ['i', 4, sub { { int => $_[0], float => unpack "f", pack "L", $_[0] }; }],
	deftype => ['v', 2, sub { { type => ETYPE_E->[$_[0] & ~DEF_SAVEGLOBAL], save => !!($_[0] & DEF_SAVEGLOBAL) }; }],
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
	[deftype => 'type'],
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

use constant LNOHEADER_T => [
	[int => 'lnotype'],
	[int => 'version'],
	[int => 'numglobaldefs'],
	[int => 'numglobals'],
	[int => 'numfielddefs'],
	[int => 'numstatements'],
];

use constant LNO_T => [
	[int => 'v'],
];

sub get_section($$$)
{
	my ($fh, $start, $len) = @_;
	seek $fh, $start, 0
		or die "seek: $!";
	$len == read $fh, my $buf, $len
		or die "short read from $start length $len (malformed progs header)";
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
			or die "short read from $start length $cnt * $itemlen $(malformed progs header)";
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

sub nfa_default_state_checker()
{
	my %seen;
	return sub
	{
		my ($ip, $state) = @_;
		return $seen{"$ip $state"}++;
	};
}

sub run_nfa($$$$$$)
{
	my ($progs, $ip, $state, $copy_handler, $state_checker, $instruction_handler) = @_;

	my $statements = $progs->{statements};

	my $nfa;
	$nfa = sub
	{
		no warnings 'recursion';

		my ($ip, $state) = @_;
		my $ret = 0;

		for(;;)
		{
			return $ret
				if $state_checker->($ip, $state);

			my $s = $statements->[$ip];
			my $c = checkop $s->{op};

			if(($ret = $instruction_handler->($ip, $state, $s, $c)))
			{
				# abort execution
				last;
			}

			if($c->{isreturn})
			{
				last;
			}
			elsif($c->{iscall})
			{
				my $func = $s->{a};
				last
					if $progs->{builtins}{error}{$func};
				$ip += 1;
			}
			elsif($c->{isjump})
			{
				if($c->{isconditional})
				{
					if(rand 2)
					{
						if(($ret = $nfa->($ip+$s->{$c->{isjump}}, $copy_handler->($state))) < 0)
						{
							last;
						}
						$ip += 1;
					}
					else
					{
						$nfa->($ip+1, $copy_handler->($state));
						$ip += $s->{$c->{isjump}};
					}
				}
				else
				{
					$ip += $s->{$c->{isjump}};
				}
			}
			else
			{
				$ip += 1;
			}
		}

		return $ret;
	};

	$nfa->($ip, $copy_handler->($state));
}

sub get_constant($$$)
{
	my ($progs, $g, $type) = @_;

	if (!defined $type) {
		$type = 'float';
		$type = 'int'
			if $g->{int} > 0 && $g->{int} < 8388608;
		$type = 'string'
			if $g->{int} > 0 && $g->{int} < length $progs->{strings};
	}

	return str($progs->{getstring}->($g->{int}))
		if $type eq 'string';
	return $g->{float}
		if $type eq 'float';
	return "'$g->{float} _ _'"
		if $type eq 'vector';
	return "entity $g->{int}"
		if $type eq 'entity';
	return ".$progs->{entityfieldnames}[$g->{int}][0]"
		if $type eq 'field' and defined $progs->{entityfieldnames}[$g->{int}][0];
	return "$g->{int}i"
		if $type eq 'int';

	return "$type($g->{int})";
}

use constant PRE_MARK_STATEMENT => "";
use constant POST_MARK_STATEMENT => "";
use constant PRE_MARK_OPERAND => "*** ";
use constant POST_MARK_OPERAND => " ***";

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

sub debugpos($$$) {
	my ($progs, $func, $ip) = @_;
	my $s = $func->{debugname};
	if ($progs->{cno}) {
		my $column = $progs->{cno}[$ip]{v};
		$s =~ s/:/:$column:/;
	}
	if ($progs->{lno}) {
		my $line = $progs->{lno}[$ip]{v};
		$s =~ s/:/:$line:/;
	}
	return $s;
}

sub disassemble_function($$;$)
{
	my ($progs, $func, $highlight) = @_;

	print "$func->{debugname}:\n";

	if($func->{first_statement} < 0) # builtin
	{
		printf INSTRUCTION_FORMAT, '', '', '.BUILTIN';
		printf OPERAND_FORMAT, -$func->{first_statement};
		print INSTRUCTION_SEPARATOR;
		return;
	}

	my $initializer = sub
	{
		my ($ofs) = @_;
		# TODO: Can we know its type?
		my $g = get_constant($progs, $progs->{globals}[$ofs]{v}, undef);
		print " = $g"
			if defined $g;
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
		$override_locals{$p} //= "argv_$_";
		for my $comp(0..($func->{parm_size}[$_]-1))
		{
			$override_locals{$p} //= "argv_$_\[$comp]";
			++$p;
		}
		printf INSTRUCTION_FORMAT, '', '', '.ARG';
		printf OPERAND_FORMAT, "argv_$_";
		print OPERAND_SEPARATOR;
		printf OPERAND_FORMAT, $func->{parm_size}[$_];
		print INSTRUCTION_SEPARATOR;
	}
	for($func->{parm_start}..($func->{parm_start} + $func->{locals} - 1))
	{
		next
			if exists $override_locals{$_};
		$override_locals{$_} = "local_$_";

		printf INSTRUCTION_FORMAT, '', '', '.LOCAL';
		printf OPERAND_FORMAT, "local_$_";
		$initializer->($_);
		print INSTRUCTION_SEPARATOR;
	}

	my $getname = sub
	{
		my ($ofs) = @_;
		return $override_locals{$ofs}
			if exists $override_locals{$ofs};
		my $def = $progs->{globaldef_byoffset}->($ofs);
		return $def->{debugname};
	};

	my $operand = sub
	{
		my ($ip, $type, $operand) = @_;
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
		elsif($type eq 'ipoffset')
		{
			printf OPERAND_FORMAT, "@{[$ip + $operand]}" . sprintf ' ($%+d)', $operand;
		}
		else
		{
			die "unknown type: $type";
		}
	};

	my $statements = $func->{statements};
	my $come_from = $func->{come_from};

	my $ipprev = undef;
	for my $ip(sort { $a <=> $b } keys %$statements)
	{
		if($ip == $func->{first_statement})
		{
			printf INSTRUCTION_FORMAT, $ip, '', '.ENTRY';
			print INSTRUCTION_SEPARATOR;
		}
		if(defined $ipprev && $ip != $ipprev + 1)
		{
			printf INSTRUCTION_FORMAT, $ip, '', '.SKIP';
			printf OPERAND_FORMAT, $ip - $ipprev - 1;
			print INSTRUCTION_SEPARATOR;
		}
		if(my $cf = $come_from->{$ip})
		{
			printf INSTRUCTION_FORMAT, $ip, '', '.XREF';
			my $cnt = 0;
			for(sort { $a <=> $b } keys %$cf)
			{
				print OPERAND_SEPARATOR
					if $cnt++;
				printf OPERAND_FORMAT, ($cf->{$_} ? 'c' : 'j') . $_ . sprintf ' ($%+d)', $_ - $ip;
			}
			print INSTRUCTION_SEPARATOR;
		}

		my $op = $progs->{statements}[$ip]{op};
		my $ipt = $progs->{statements}[$ip];
		my $opprop = checkop $op;

		if($highlight and $highlight->{$ip})
		{
			for(values %{$highlight->{$ip}})
			{
				for(sort keys %$_)
				{
					print PRE_MARK_STATEMENT;
					printf INSTRUCTION_FORMAT, '', '<!>', '.WARN';
					my $pos = debugpos $progs, $func, $ip;
					printf OPERAND_FORMAT, "$_ (in $pos)";
					print INSTRUCTION_SEPARATOR;
				}
			}
		}

		print PRE_MARK_STATEMENT
			if $highlight and $highlight->{$ip};

		my $showip = $opprop->{isjump};
		printf INSTRUCTION_FORMAT, $showip ? $ip : '', $highlight->{$ip} ? '<!>' : '', $op;

		my $cnt = 0;
		for my $o(qw(a b c))
		{
			next
				if not defined $opprop->{$o};
			print OPERAND_SEPARATOR
				if $cnt++;
			print PRE_MARK_OPERAND
				if $highlight and $highlight->{$ip} and $highlight->{$ip}{$o};
			$operand->($ip, $opprop->{$o}, $ipt->{$o});
			print POST_MARK_OPERAND
				if $highlight and $highlight->{$ip} and $highlight->{$ip}{$o};
		}

		print POST_MARK_STATEMENT
			if $highlight and $highlight->{$ip};

		print INSTRUCTION_SEPARATOR;
	}
}

sub find_uninitialized_locals($$)
{
	my ($progs, $func) = @_;

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
	my %watchme = map { $_ => WATCHME_X } ($func->{parm_start} .. ($func->{parm_start} + $func->{locals} - 1));

	for(keys %{$progs->{temps}})
	{
		next
			if exists $watchme{$_};
		if($progs->{temps}{$_})
		{
			# shared temp
			$watchme{$_} = WATCHME_T | WATCHME_X
		}
		else
		{
			# unique temp
			$watchme{$_} = WATCHME_X
		}
	}

	$watchme{$_} |= WATCHME_R
		for keys %{$func->{globals_read}};
	$watchme{$_} |= WATCHME_W
		for keys %{$func->{globals_written}};

	my %write_places = ();
	for my $ofs(keys %{$func->{globals_written}})
	{
		next
			unless exists $watchme{$ofs} and $watchme{$ofs} & WATCHME_X;
		for my $ip(keys %{$func->{globals_written}{$ofs}})
		{
			for my $op(keys %{$func->{globals_written}{$ofs}{$ip}})
			{
				push @{$write_places{$ip}{$op}}, $ofs;
			}
		}
	}

	for(keys %watchme)
	{
		delete $watchme{$_}
			if ($watchme{$_} & (WATCHME_R | WATCHME_W | WATCHME_X)) != (WATCHME_R | WATCHME_W | WATCHME_X);
	}

	return
		if not keys %watchme;

	for(keys %watchme)
	{
		$watchme{$_} = {
			flags => $watchme{$_},
			valid => [0, undef, undef]
		};
	}

	# mark parameters as initialized
	for($func->{parm_start} .. ($p-1))
	{
		$watchme{$_}{valid} = [1, undef, undef]
			if defined $watchme{$_};
	}

	my %warned = ();
	my %ip_seen = ();
	run_nfa $progs, $func->{first_statement}, \%watchme,
		sub {
			my ($h) = @_;
			return { map { $_ => { %{$h->{$_}} } } keys %$h };
		},
		sub {
			my ($ip, $state) = @_;

			my $s = $ip_seen{$ip};
			if($s)
			{
				# if $state is stronger or equal to $s, return 1

				for(keys %$state)
				{
					if($state->{$_}{valid}[0] < $s->{$_})
					{
						# The current state is LESS valid than the previously run one. We NEED to run this.
						# The saved state can safely become the intersection [citation needed].
						for(keys %$state)
						{
							$s->{$_} = $state->{$_}{valid}[0]
								if $state->{$_}{valid}[0] < $s->{$_};
						}
						return 0;
					}
				}
				# if we get here, $state is stronger or equal. No need to try it.
				return 1;
			}
			else
			{
				# Never seen this IP yet.
				$ip_seen{$ip} = { map { ($_ => $state->{$_}{valid}[0]); } keys %$state };
				return 0;
			}
		},
		sub {
			my ($ip, $state, $s, $c) = @_;
			my $op = $s->{op};

			# QCVM BUG: RETURN always takes vector, there is no float equivalent
			my $return_hack = $c->{isreturn} // 0;

			if($op eq 'STORE_V')
			{
				# COMPILER BUG of QCC: params are always copied using STORE_V
				if($s->{b} >= 4 && $s->{b} < 28) # parameter range
				{
					$return_hack = 1;
				}
			}

			if($c->{isinvalid})
			{
				++$warned{$ip}{''}{"Invalid opcode"};
			}
			for(qw(a b c))
			{
				my $type = $c->{$_};
				next
					unless defined $type;

				my $ofs = $s->{$_};

				my $read = sub
				{
					my ($ofs) = @_;
					++$return_hack
						if $return_hack;
					return
						if not exists $state->{$ofs};
					my $valid = $state->{$ofs}{valid};
					if($valid->[0] == 0)
					{
						# COMPILER BUG of FTEQCC: AND and OR may take uninitialized as second argument (logicops)
						if($return_hack <= 2 and ($op ne 'OR' && $op ne 'AND' || $_ ne 'b'))
						{
							++$warned{$ip}{$_}{"Use of uninitialized value"};
						}
					}
					elsif($valid->[0] < 0)
					{
						# COMPILER BUG of FTEQCC: AND and OR may take uninitialized as second argument (logicops)
						if($return_hack <= 2 and ($op ne 'OR' && $op ne 'AND' || $_ ne 'b'))
						{
							++$warned{$ip}{$_}{"Use of temporary across CALL"};
						}
					}
					else
					{
						# it's VALID
						if(defined $valid->[1])
						{
							delete $write_places{$valid->[1]}{$valid->[2]};
						}
					}
				};
				my $write = sub
				{
					my ($ofs) = @_;
					$state->{$ofs}{valid} = [1, $ip, $_]
						if exists $state->{$ofs};
				};

				if($type eq 'inglobal' || $type eq 'inglobalfunc')
				{
					$read->($ofs);
				}
				elsif($type eq 'inglobalvec')
				{
					$read->($ofs);
					$read->($ofs+1);
					$read->($ofs+2);
				}
				elsif($type eq 'outglobal')
				{
					$write->($ofs);
				}
				elsif($type eq 'outglobalvec')
				{
					$write->($ofs);
					$write->($ofs+1);
					$write->($ofs+2);
				}
				elsif($type eq 'ipoffset')
				{
					++$warned{$ip}{$_}{"Endless loop"}
						if $ofs == 0;
					++$warned{$ip}{$_}{"No-operation jump"}
						if $ofs == 1;
				}
			}
			if($c->{iscall})
			{
				# builtin calls may clobber stuff
				my $func = $s->{a};
				my $funcid = $progs->{globals}[$func]{v}{int};
				my $funcobj = $progs->{functions}[$funcid];
				if(!$funcobj || $funcobj->{first_statement} >= 0)
				{
					# invalidate temps
					for(values %$state)
					{
						if($_->{flags} & WATCHME_T)
						{
							$_->{valid} = [-1, undef, undef];
						}
					}
				}
			}

			return 0;
		};

	for my $ip(keys %write_places)
	{
		for my $operand(keys %{$write_places{$ip}})
		{
			# TODO verify it
			my %left = map { $_ => 1 } @{$write_places{$ip}{$operand}};
			my $isread = 0;

			my %writeplace_seen = ();
			run_nfa $progs, $ip+1, \%left,
				sub
				{
					return { %{$_[0]} };
				},
				sub
				{
					my ($ip, $state) = @_;
					return $writeplace_seen{"$ip " . join " ", sort keys %$state}++;
				},
				sub
				{
					my ($ip, $state, $s, $c) = @_;
					for(qw(a b c))
					{
						my $type = $c->{$_};
						next
							unless defined $type;

						my $ofs = $s->{$_};
						if($type eq 'inglobal' || $type eq 'inglobalfunc')
						{
							if($state->{$ofs})
							{
								$isread = 1;
								return -1; # exit TOTALLY
							}
						}
						elsif($type eq 'inglobalvec')
						{
							if($state->{$ofs} || $state->{$ofs+1} || $state->{$ofs+2})
							{
								$isread = 1;
								return -1; # exit TOTALLY
							}
						}
						elsif($type eq 'outglobal')
						{
							delete $state->{$ofs};
							return 1
								if !%$state;
						}
						elsif($type eq 'outglobalvec')
						{
							delete $state->{$ofs};
							delete $state->{$ofs+1};
							delete $state->{$ofs+2};
							return 1
								if !%$state;
						}
					}
					return 0;
				};

			if(!$isread)
			{
				++$warned{$ip}{$operand}{"Value is never used"};
			}
		}
	}

	my %solid_seen = ();
	run_nfa $progs, $func->{first_statement}, do { my $state = -1; \$state; },
		sub
		{
			my $state = ${$_[0]};
			return \$state;
		},
		sub
		{
			my ($ip, $state) = @_;
			return $solid_seen{"$ip $$state"}++;
		},
		sub
		{
			my ($ip, $state, $s, $c) = @_;

			if($s->{op} eq 'ADDRESS')
			{
				my $field_ptr_ofs = $s->{b};
				my $def = $progs->{globaldef_byoffset}->($field_ptr_ofs);
				use Data::Dumper;
				if (($def->{globaltype} eq 'read_only' || $def->{globaltype} eq 'const') &&
						grep { $_ eq 'solid' } @{$progs->{entityfieldnames}[$progs->{globals}[$field_ptr_ofs]{v}{int}]})
				{
					# Taking address of 'solid' for subsequent write!
					# TODO check if this address is then actually used in STOREP.
					$$state = $ip;
				}
			}

			if($c->{iscall})
			{
				# TODO check if the entity passed is actually the one on which solid was set.
				my $func = $s->{a};
				if ($progs->{builtins}{setmodel}{$func} || $progs->{builtins}{setmodelindex}{$func} || $progs->{builtins}{setorigin}{$func} || $progs->{builtins}{setsize}{$func})
				{
					# All is clean.
					$$state = -1;
				}
			}

			if($c->{isreturn})
			{
				if ($$state >= 0) {
					++$warned{$$state}{''}{"Changing .solid without setmodel/setmodelindex/setorigin/setsize breaks area grid linking in Quake [write is here]"};
					++$warned{$ip}{''}{"Changing .solid without setmodel/setmodelindex/setorigin/setsize breaks area grid linking in Quake [return is here]"};
				}
			}

			return 0;
		};

	disassemble_function($progs, $func, \%warned)
		if keys %warned;
}

use constant DEFAULTGLOBALS => [
	"OFS_NULL",
	"OFS_RETURN",
	"OFS_RETURN[1]",
	"OFS_RETURN[2]",
	"OFS_PARM0",
	"OFS_PARM0[1]",
	"OFS_PARM0[2]",
	"OFS_PARM1",
	"OFS_PARM1[1]",
	"OFS_PARM1[2]",
	"OFS_PARM2",
	"OFS_PARM2[1]",
	"OFS_PARM2[2]",
	"OFS_PARM3",
	"OFS_PARM3[1]",
	"OFS_PARM3[2]",
	"OFS_PARM4",
	"OFS_PARM4[1]",
	"OFS_PARM4[2]",
	"OFS_PARM5",
	"OFS_PARM5[1]",
	"OFS_PARM5[2]",
	"OFS_PARM6",
	"OFS_PARM6[1]",
	"OFS_PARM6[2]",
	"OFS_PARM7",
	"OFS_PARM7[1]",
	"OFS_PARM7[2]"
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

sub detect_constants($)
{
	my ($progs) = @_;
	use constant GLOBALFLAG_R => 1; # read
	use constant GLOBALFLAG_W => 2; # written
	use constant GLOBALFLAG_S => 4; # saved
	use constant GLOBALFLAG_I => 8; # initialized
	use constant GLOBALFLAG_N => 16; # named
	use constant GLOBALFLAG_Q => 32; # unique to function
	use constant GLOBALFLAG_U => 64; # unused
	use constant GLOBALFLAG_P => 128; # possibly parameter passing
	use constant GLOBALFLAG_D => 256; # has a def
	my @globalflags = (GLOBALFLAG_Q | GLOBALFLAG_U) x (@{$progs->{globals}} + 2);

	for(@{$progs->{functions}})
	{
		for(keys %{$_->{globals_used}})
		{
			if($globalflags[$_] & GLOBALFLAG_U)
			{
				$globalflags[$_] &= ~GLOBALFLAG_U;
			}
			elsif($globalflags[$_] & GLOBALFLAG_Q)
			{
				$globalflags[$_] &= ~GLOBALFLAG_Q;
			}
		}
		$globalflags[$_] |= GLOBALFLAG_R
			for keys %{$_->{globals_read}};
		$globalflags[$_] |= GLOBALFLAG_W
			for keys %{$_->{globals_written}};
		next
			if $_->{first_statement} < 0;
		for my $ip($_->{first_statement} .. (@{$progs->{statements}}-1))
		{
			my $s = $progs->{statements}[$ip];
			if($s->{op} eq 'STORE_V')
			{
				$globalflags[$s->{a}] |= GLOBALFLAG_P
					if $s->{b} >= $_->{parm_start} and $s->{b} < $_->{parm_start} + $_->{locals};
				$globalflags[$s->{a}+1] |= GLOBALFLAG_P
					if $s->{b}+1 >= $_->{parm_start} and $s->{b}+1 < $_->{parm_start} + $_->{locals};
				$globalflags[$s->{a}+2] |= GLOBALFLAG_P
					if $s->{b}+2 >= $_->{parm_start} and $s->{b}+2 < $_->{parm_start} + $_->{locals};
			}
			elsif($s->{op} =~ /^STORE_/)
			{
				$globalflags[$s->{a}] |= GLOBALFLAG_P
					if $s->{b} >= $_->{parm_start} and $s->{b} < $_->{parm_start} + $_->{locals};
			}
			else
			{
				last;
			}
		}
	}

	# parameter passing globals are only ever used in STORE_ instructions
	for my $s(@{$progs->{statements}})
	{
		next
			if $s->{op} =~ /^STORE_/;

		my $c = checkop $s->{op};

		for(qw(a b c))
		{
			my $type = $c->{$_};
			next
				unless defined $type;

			my $ofs = $s->{$_};
			if($type eq 'inglobal' || $type eq 'inglobalfunc' || $type eq 'outglobal')
			{
				$globalflags[$ofs] &= ~GLOBALFLAG_P;
			}
			if($type eq 'inglobalvec' || $type eq 'outglobalvec')
			{
				$globalflags[$ofs] &= ~GLOBALFLAG_P;
				$globalflags[$ofs+1] &= ~GLOBALFLAG_P;
				$globalflags[$ofs+2] &= ~GLOBALFLAG_P;
			}
		}
	}

	my %offsets_saved = ();
	for(@{$progs->{globaldefs}})
	{
		my $type = $_->{type};
		my $name = $progs->{getstring}->($_->{s_name});
		$name = ''
			if $name eq 'IMMEDIATE'; # for fteqcc I had: or $name =~ /^\./;
		$_->{debugname} = $name
			if $name ne '';
		$globalflags[$_->{ofs}] |= GLOBALFLAG_D;
		if($type->{save})
		{
			$globalflags[$_->{ofs}] |= GLOBALFLAG_S;
		}
		if(defined $_->{debugname})
		{
			$globalflags[$_->{ofs}] |= GLOBALFLAG_N;
		}
	}
	# fix up vectors
	my @extradefs = ();
	for(@{$progs->{globaldefs}})
	{
		my $type = $_->{type};
		for my $i(1..(typesize($type->{type})-1))
		{
			# add missing def
			if(!($globalflags[$_->{ofs}+$i] & GLOBALFLAG_D))
			{
				print "Missing globaldef for a component@{[defined $_->{debugname} ? ' of ' . $_->{debugname} : '']} at $_->{ofs}+$i\n";
				push @extradefs, {
					type => {
						saved => 0,
						type => 'float'
					},
					ofs => $_->{ofs} + $i,
					debugname => defined $_->{debugname} ? $_->{debugname} . "[$i]" : undef
				};
			}
			# "saved" and "named" states hit adjacent globals too
			$globalflags[$_->{ofs}+$i] |= $globalflags[$_->{ofs}] & (GLOBALFLAG_S | GLOBALFLAG_N | GLOBALFLAG_D);
		}
	}
	push @{$progs->{globaldefs}}, @extradefs;

	my %offsets_initialized = ();
	for(0..(@{$progs->{globals}}-1))
	{
		if($progs->{globals}[$_]{v}{int})
		{
			$globalflags[$_] |= GLOBALFLAG_I;
		}
	}

	my @globaltypes = (undef) x @{$progs->{globals}};

	my %istemp = ();
	for(0..(@{$progs->{globals}}-1))
	{
		next
			if $_ < @{(DEFAULTGLOBALS)};
		if(($globalflags[$_] & (GLOBALFLAG_R | GLOBALFLAG_W)) == 0)
		{
			$globaltypes[$_] = "unused";
		}
		elsif(($globalflags[$_] & (GLOBALFLAG_R | GLOBALFLAG_W)) == GLOBALFLAG_R)
		{
			# so it is ro
			if(($globalflags[$_] & GLOBALFLAG_N) == GLOBALFLAG_N)
			{
				$globaltypes[$_] = "read_only";
			}
			elsif(($globalflags[$_] & GLOBALFLAG_S) == 0)
			{
				$globaltypes[$_] = "const";
			}
			else
			{
				$globaltypes[$_] = "read_only";
			}
		}
		elsif(($globalflags[$_] & (GLOBALFLAG_R | GLOBALFLAG_W)) == GLOBALFLAG_W)
		{
			$globaltypes[$_] = "write_only";
		}
		else
		{
			# now we know it is rw
			if(($globalflags[$_] & GLOBALFLAG_N) == GLOBALFLAG_N)
			{
				$globaltypes[$_] = "global";
			}
			elsif(($globalflags[$_] & (GLOBALFLAG_S | GLOBALFLAG_I)) == 0)
			{
				if($globalflags[$_] & GLOBALFLAG_P)
				{
					$globaltypes[$_] = "OFS_PARM";
				}
				elsif($globalflags[$_] & GLOBALFLAG_Q)
				{
					$globaltypes[$_] = "uniquetemp";
					$istemp{$_} = 0;
				}
				else
				{
					$globaltypes[$_] = "temp";
					$istemp{$_} = 1;
				}
			}
			elsif(($globalflags[$_] & (GLOBALFLAG_S | GLOBALFLAG_I)) == GLOBALFLAG_I)
			{
				$globaltypes[$_] = "not_saved";
			}
			else
			{
				$globaltypes[$_] = "global";
			}
		}
	}
	$progs->{temps} = \%istemp;

	# globaldefs
	my @globaldefs = (undef) x @{$progs->{globals}};
	for(@{$progs->{globaldefs}})
	{
		$globaldefs[$_->{ofs}] //= $_
			if defined $_->{debugname};
	}
	for(@{$progs->{globaldefs}})
	{
		$globaldefs[$_->{ofs}] //= $_;
	}
	for(0..(@{$progs->{globals}}-1))
	{
		$globaldefs[$_] //= {
			ofs => $_,
			s_name => undef,
			debugname => undef,
			type => undef
		};
	}
	for(0..(@{(DEFAULTGLOBALS)}-1))
	{
		$globaldefs[$_] = { ofs => $_, s_name => undef, debugname => DEFAULTGLOBALS->[$_], type => undef };
		$globaltypes[$_] = 'defglobal';
	}
	my %globaldefs_namecount = ();
	for(@globaldefs)
	{
		$_->{globaltype} = $globaltypes[$_->{ofs}];
		if(defined $_->{debugname})
		{
			# already has debugname
		}
		elsif($_->{globaltype} eq 'const')
		{
			$_->{debugname} = get_constant($progs, $progs->{globals}[$_->{ofs}]{v}, $_->{type}{type});
		}
		else
		{
			$_->{debugname} = "$_->{globaltype}_$_->{ofs}";
		}
		++$globaldefs_namecount{$_->{debugname}};
	}
	for(@globaldefs)
	{
		next
			if $globaldefs_namecount{$_->{debugname}} <= 1 && !$ENV{FORCE_OFFSETS};
		#print "Not unique: $_->{debugname} at $_->{ofs}\n";
		$_->{debugname} .= "\@$_->{ofs}";
	}
	$progs->{globaldef_byoffset} = sub
	{
		my ($ofs) = @_;
		my $def = $globaldefs[$ofs];
		return $def;
	};
}

sub parse_progs($$)
{
	my ($fh, $lnofh) = @_;

	my %p = ();

	print STDERR "Parsing header...\n";
	$p{header} = parse_section $fh, DPROGRAMS_T, 0, undef, 1;
	
	if (defined $lnofh) {
		print STDERR "Parsing LNO...\n";
		my $lnoheader = parse_section $lnofh, LNOHEADER_T, 0, undef, 1;
		eval {
			die "Not a LNOF"
				if $lnoheader->{lnotype} != unpack 'V', 'LNOF';
			die "Not version 1"
				if $lnoheader->{version} != 1;
			die "Not same count of globaldefs"
				if $lnoheader->{numglobaldefs} != $p{header}{numglobaldefs};
			die "Not same count of globals"
				if $lnoheader->{numglobals} != $p{header}{numglobals};
			die "Not same count of fielddefs"
				if $lnoheader->{numfielddefs} != $p{header}{numfielddefs};
			die "Not same count of statements"
				if $lnoheader->{numstatements} != $p{header}{numstatements};
			$p{lno} = [parse_section $lnofh, LNO_T, 24, undef, $lnoheader->{numstatements}];
			eval {
				$p{lno} = [parse_section $lnofh, LNO_T, 24, undef, $lnoheader->{numstatements} * 2];
				$p{cno} = [splice $p{lno}, $lnoheader->{numstatements}];
				print STDERR "Cool, this LNO even has column number info!\n";
			};
		} or warn "Skipping LNO: $@";
	}

	print STDERR "Parsing strings...\n";
	$p{strings} = get_section $fh, $p{header}{ofs_strings}, $p{header}{numstrings};
	$p{getstring} = sub
	{
		my ($startpos) = @_;
		my $endpos = index $p{strings}, "\0", $startpos;
		return substr $p{strings}, $startpos, $endpos - $startpos;
	};

	print STDERR "Parsing globals...\n";
	$p{globals} = [parse_section $fh, DGLOBAL_T, $p{header}{ofs_globals}, undef, $p{header}{numglobals}];

	print STDERR "Parsing globaldefs...\n";
	$p{globaldefs} = [parse_section $fh, DDEF_T, $p{header}{ofs_globaldefs}, undef, $p{header}{numglobaldefs}];

	print STDERR "Range checking globaldefs...\n";
	for(0 .. (@{$p{globaldefs}}-1))
	{
		my $g = $p{globaldefs}[$_];
		die "Out of range name in globaldef $_"
			if $g->{s_name} < 0 || $g->{s_name} >= length $p{strings};
		my $name = $p{getstring}->($g->{s_name});
		die "Out of range ofs $g->{ofs} in globaldef $_ (name: \"$name\")"
			if $g->{ofs} >= $p{globals};
	}

	print STDERR "Parsing fielddefs...\n";
	$p{fielddefs} = [parse_section $fh, DDEF_T, $p{header}{ofs_fielddefs}, undef, $p{header}{numfielddefs}];

	print STDERR "Range checking fielddefs...\n";
	for(0 .. (@{$p{fielddefs}}-1))
	{
		my $g = $p{fielddefs}[$_];
		die "Out of range name in fielddef $_"
			if $g->{s_name} < 0 || $g->{s_name} >= length $p{strings};
		my $name = $p{getstring}->($g->{s_name});
		die "Out of range ofs $g->{ofs} in fielddef $_ (name: \"$name\")"
			if $g->{ofs} >= $p{header}{entityfields};
		push @{$p{entityfieldnames}[$g->{ofs}]}, $name;
	}

	print STDERR "Parsing statements...\n";
	$p{statements} = [parse_section $fh, DSTATEMENT_T, $p{header}{ofs_statements}, undef, $p{header}{numstatements}];

	print STDERR "Parsing functions...\n";
	$p{functions} = [parse_section $fh, DFUNCTION_T, $p{header}{ofs_functions}, undef, $p{header}{numfunctions}];

	print STDERR "Range checking functions...\n";
	for(0 .. (@{$p{functions}} - 1))
	{
		my $f = $p{functions}[$_];
		die "Out of range name in function $_"
			if $f->{s_name} < 0 || $f->{s_name} >= length $p{strings};
		my $name = $p{getstring}->($f->{s_name});
		die "Out of range file in function $_"
			if $f->{s_file} < 0 || $f->{s_file} >= length $p{strings};
		my $file = $p{getstring}->($f->{s_file});
		die "Out of range first_statement in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
			if $f->{first_statement} >= @{$p{statements}};
		if($f->{first_statement} >= 0)
		{
			die "Out of range parm_start in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
				if $f->{parm_start} < 0 || $f->{parm_start} >= @{$p{globals}};
			die "Out of range locals in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
				if $f->{locals} < 0 || $f->{parm_start} + $f->{locals} > @{$p{globals}};
			die "Out of range numparms $f->{numparms} in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
				if $f->{numparms} < 0 || $f->{numparms} > 8;
			my $totalparms = 0;
			for(0..($f->{numparms}-1))
			{
				die "Out of range parm_size[$_] in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
					unless { 0 => 1, 1 => 1, 3 => 1 }->{$f->{parm_size}[$_]};
				$totalparms += $f->{parm_size}[$_];
			}
			die "Out of range parms in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
				if $f->{parm_start} + $totalparms > @{$p{globals}};
			die "More parms than locals in function $_ (name: \"$name\", file: \"$file\", first statement: $f->{first_statement})"
				if $totalparms > $f->{locals};
		}
	}

	print STDERR "Range checking statements...\n";
	for my $ip(0 .. (@{$p{statements}}-1))
	{
		my $s = $p{statements}[$ip];
		my $c = checkop $s->{op};

		for(qw(a b c))
		{
			my $type = $c->{$_};
			next
				unless defined $type;

			if($type eq 'inglobal' || $type eq 'inglobalfunc')
			{
				$s->{$_} &= 0xFFFF;
				die "Out of range global offset in statement $ip - cannot continue"
					if $s->{$_} >= @{$p{globals}};
			}
			elsif($type eq 'inglobalvec')
			{
				$s->{$_} &= 0xFFFF;
				if($c->{isreturn})
				{
					die "Out of range global offset in statement $ip - cannot continue"
						if $s->{$_} >= @{$p{globals}};
					print "Potentially out of range global offset in statement $ip - may crash engines"
						if $s->{$_} >= @{$p{globals}}-2;
				}
				else
				{
					die "Out of range global offset in statement $ip - cannot continue"
						if $s->{$_} >= @{$p{globals}}-2;
				}
			}
			elsif($type eq 'outglobal')
			{
				$s->{$_} &= 0xFFFF;
				die "Out of range global offset in statement $ip - cannot continue"
					if $s->{$_} >= @{$p{globals}};
			}
			elsif($type eq 'outglobalvec')
			{
				$s->{$_} &= 0xFFFF;
				die "Out of range global offset in statement $ip - cannot continue"
					if $s->{$_} >= @{$p{globals}}-2;
			}
			elsif($type eq 'ipoffset')
			{
				die "Out of range GOTO/IF/IFNOT in statement $ip - cannot continue"
					if $ip + $s->{$_} < 0 || $ip + $s->{$_} >= @{$p{statements}};
			}
		}
	}

	print STDERR "Looking for error(), setmodel(), setmodelindex(), setorigin(), setsize()...\n";
	$p{builtins} = { error => {}, setmodel => {}, setmodelindex => {}, setorigin => {}, setsize => {} };
	for(@{$p{globaldefs}})
	{
		my $name = $p{getstring}($_->{s_name});
		next
			if not exists $p{builtins}{$name};
		my $v = $p{globals}[$_->{ofs}]{v}{int};
		next
			if $v <= 0 || $v >= @{$p{functions}};
		my $first = $p{functions}[$v]{first_statement};
		next
			if $first >= 0;
		print STDERR "Detected $name() at offset $_->{ofs} (builtin #@{[-$first]})\n";
		$p{builtins}{$name}{$_->{ofs}} = 1;
	}

	print STDERR "Scanning functions...\n";
	for(@{$p{functions}})
	{
		my $file = $p{getstring}->($_->{s_file});
		my $name = $p{getstring}->($_->{s_name});
		$name = "$file:$name"
			if length $file;
		$_->{debugname} = $name;

		next
			if $_->{first_statement} < 0;

		my %statements = ();
		my %come_from = ();
		my %go_to = ();
		my %globals_read = ();
		my %globals_written = ();
		my %globals_used = ();

		if($_->{first_statement} >= 0)
		{
			run_nfa \%p, $_->{first_statement}, "", id, nfa_default_state_checker,
				sub
				{
					my ($ip, $state, $s, $c) = @_;
					++$statements{$ip};

					if(my $j = $c->{isjump})
					{
						my $t = $ip + $s->{$j};
						$come_from{$t}{$ip} = $c->{isconditional};
						$go_to{$ip}{$t} = $c->{isconditional};
					}

					for my $o(qw(a b c))
					{
						my $type = $c->{$o}
							or next;
						my $ofs = $s->{$o};

						my $read = sub
						{
							my ($ofs) = @_;
							$globals_read{$ofs}{$ip}{$o} = 1;
							$globals_used{$ofs} = 1;
						};
						my $write = sub
						{
							my ($ofs) = @_;
							$globals_written{$ofs}{$ip}{$o} = 1;
							$globals_used{$ofs} = 1;
						};

						if($type eq 'inglobal' || $type eq 'inglobalfunc')
						{
							$read->($ofs);
						}
						elsif($type eq 'inglobalvec')
						{
							$read->($ofs);
							$read->($ofs+1);
							$read->($ofs+2);
						}
						elsif($type eq 'outglobal')
						{
							$write->($ofs);
						}
						elsif($type eq 'outglobalvec')
						{
							$write->($ofs);
							$write->($ofs+1);
							$write->($ofs+2);
						}
					}

					return 0;
				};
		}

		$_->{statements} = \%statements;
		$_->{come_from} = \%come_from;
		$_->{go_to} = \%go_to;
		$_->{globals_read} = \%globals_read;
		$_->{globals_written} = \%globals_written;
		$_->{globals_used} = \%globals_used;

		# using this info, we could now identify basic blocks
	}

	print STDERR "Detecting constants and temps, and naming...\n";
	detect_constants \%p;

	if($ENV{DUMP})
	{
		use Data::Dumper;
		print Dumper \%p;
		return;
	}

	# what do we want to do?
	my $checkfunc = \&find_uninitialized_locals;
	if($ENV{DISASSEMBLE})
	{
		$checkfunc = \&disassemble_function;
	}
	for(sort { $a->{debugname} cmp $b->{debugname} } @{$p{functions}})
	{
		$checkfunc->(\%p, $_);
	}
}

for my $progs (@ARGV) {
	my $lno = "$progs.lno";
	$lno =~ s/\.dat\.lno$/.lno/;

	open my $fh, '<', $progs
		or die "$progs: $!";

	open my $lnofh, '<', $lno
		or warn "$lno: $!";

	parse_progs $fh, $lnofh;
}
