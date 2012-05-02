use strict;
use warnings;
use Digest::SHA;

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
				my $funcid = $progs->{globals}[$func]{v}{int};
				my $funcobj = $progs->{functions}[$funcid];
				if($funcobj && $funcobj->{first_statement} < 0) # builtin
				{
					my $def = $progs->{globaldef_byoffset}->($func);
					last
						if $def->{debugname} eq '$error';
				}
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

sub get_constant($$)
{
	my ($progs, $g) = @_;
	if($g->{int} == 0)
	{
		return 0;
	}
	elsif($g->{int} > 0 && $g->{int} < 8388608)
	{
		if($g->{int} < length $progs->{strings} && $g->{int} > 0)
		{
			return str($progs->{getstring}->($g->{int}));
		}
		else
		{
			return $g->{int} . "i";
		}
	}
	else
	{
		return $g->{float};
	}
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

sub disassemble_function($$;$)
{
	my ($progs, $func, $highlight) = @_;

	print "$func->{debugname}:\n";

	my $initializer = sub
	{
		my ($ofs) = @_;
		my $g = get_constant($progs, $progs->{globals}[$ofs]{v});
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

	my %statements = ();
	my %come_from = ();
	run_nfa $progs, $func->{first_statement}, "", id, nfa_default_state_checker,
		sub
		{
			my ($ip, $state, $s, $c) = @_;
			++$statements{$ip};

			if(my $j = $c->{isjump})
			{
				my $t = $ip + $s->{$j};
				$come_from{$t}{$ip} = $c->{isconditional};
			}

			return 0;
		};

	my $ipprev = undef;
	for my $ip(sort { $a <=> $b } keys %statements)
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
		if(my $cf = $come_from{$ip})
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

		print PRE_MARK_STATEMENT
			if $highlight and $highlight->{$ip};

		my $showip = $opprop->{isjump};
		printf INSTRUCTION_FORMAT, $showip ? $ip : '', $highlight->{$ip} ? "<!>" : "", $op;

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
		$watchme{$_} = WATCHME_T | WATCHME_X
			if not exists $watchme{$_};
	}

	my %write_places = ();
	run_nfa $progs, $func->{first_statement}, "", id, nfa_default_state_checker,
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
					$watchme{$ofs} |= WATCHME_R;
				}
				elsif($type eq 'inglobalvec')
				{
					$watchme{$ofs} |= WATCHME_R;
					$watchme{$ofs+1} |= WATCHME_R;
					$watchme{$ofs+2} |= WATCHME_R;
				}
				elsif($type eq 'outglobal')
				{
					$watchme{$ofs} |= WATCHME_W;
					$write_places{$ip}{$_} = [$ofs]
						if $watchme{$ofs} & WATCHME_X;
				}
				elsif($type eq 'outglobalvec')
				{
					$watchme{$ofs} |= WATCHME_W;
					$watchme{$ofs+1} |= WATCHME_W;
					$watchme{$ofs+2} |= WATCHME_W;
					my @l = grep { $watchme{$_} & WATCHME_X } $ofs .. ($ofs+2);
					$write_places{$ip}{$_} = \@l
						if @l;
				}
			}

			return 0;
		};

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
	# an initial run of STORE instruction is for receiving extra parameters
	# (beyond 8). Only possible if the function is declared as having 8 params.
	# Extra parameters behave otherwise like temps, but are initialized at
	# startup.
	for($func->{first_statement} .. (@{$progs->{statements}}-1))
	{
		my $s = $progs->{statements}[$_];
		if($s->{op} eq 'STORE_V')
		{
			$watchme{$s->{a}}{valid} = [1, undef, undef]
				if defined $watchme{$s->{a}};
			$watchme{$s->{a}+1}{valid} = [1, undef, undef]
				if defined $watchme{$s->{a}+1};
			$watchme{$s->{a}+2}{valid} = [1, undef, undef]
				if defined $watchme{$s->{a}+2};
		}
		elsif($s->{op} =~ /^STORE_/)
		{
			$watchme{$s->{a}}{valid} = [1, undef, undef]
				if defined $watchme{$s->{a}};
		}
		else
		{
			last;
		}
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

			my $return_hack = $c->{isreturn} // 0;

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
						if($return_hack <= 2 and ($op ne 'OR' && $op ne 'AND' || $_ ne 'b')) # fteqcc logicops cause this
						{
							print "; Use of uninitialized value $ofs in $func->{debugname} at $ip.$_\n";
							++$warned{$ip}{$_};
						}
					}
					elsif($valid->[0] < 0)
					{
						if($return_hack <= 2 and ($op ne 'OR' && $op ne 'AND' || $_ ne 'b')) # fteqcc logicops cause this
						{
							print "; Use of temporary $ofs across CALL in $func->{debugname} at $ip.$_\n";
							++$warned{$ip}{$_};
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
				print "; Value is never used in $func->{debugname} at $ip.$operand\n";
				++$warned{$ip}{$operand};
			}
		}
	}
	
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

sub parse_progs($)
{
	my ($fh) = @_;

	my %p = ();

	print STDERR "Parsing header...\n";
	$p{header} = parse_section $fh, DPROGRAMS_T, 0, undef, 1;
	
	print STDERR "Parsing strings...\n";
	$p{strings} = get_section $fh, $p{header}{ofs_strings}, $p{header}{numstrings};
	$p{getstring} = sub
	{
		my ($startpos) = @_;
		my $endpos = index $p{strings}, "\0", $startpos;
		return substr $p{strings}, $startpos, $endpos - $startpos;
	};

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

	print STDERR "Detecting constants and temps...\n";
	use constant GLOBALFLAG_R => 1;
	use constant GLOBALFLAG_W => 2;
	use constant GLOBALFLAG_S => 4;
	use constant GLOBALFLAG_I => 8;
	use constant GLOBALFLAG_N => 16;
	my @globalflags = (0) x @{$p{globals}};
	for my $s(@{$p{statements}})
	{
		my $c = checkop $s->{op};

		for(qw(a b c))
		{
			my $type = $c->{$_};
			next
				unless defined $type;

			my $ofs = $s->{$_};

			my $read = sub
			{
				my ($ofs) = @_;
				$globalflags[$ofs] |= GLOBALFLAG_R;
			};
			my $write = sub
			{
				my ($ofs) = @_;
				$globalflags[$ofs] |= GLOBALFLAG_W;
			};

			if($type eq 'inglobal' || $type eq 'inglobalfunc')
			{
				$s->{$_} = $ofs = ($ofs & 0xFFFF);
				$read->($ofs);
			}
			elsif($type eq 'inglobalvec')
			{
				$s->{$_} = $ofs = ($ofs & 0xFFFF);
				$read->($ofs);
				$read->($ofs+1);
				$read->($ofs+2);
			}
			elsif($type eq 'outglobal')
			{
				$s->{$_} = $ofs = ($ofs & 0xFFFF);
				$write->($ofs);
			}
			elsif($type eq 'outglobalvec')
			{
				$s->{$_} = $ofs = ($ofs & 0xFFFF);
				$write->($ofs);
				$write->($ofs+1);
				$write->($ofs+2);
			}
		}

	}

	my %offsets_saved = ();
	for(@{$p{globaldefs}})
	{
		my $type = $_->{type};
		my $name = $p{getstring}->($_->{s_name});
		if($type->{save})
		{
			for my $i(0..(typesize($_->{type}{type})-1))
			{
				$globalflags[$_->{ofs}] |= GLOBALFLAG_S;
			}
		}
		if($name ne "")
		{
			for my $i(0..(typesize($_->{type}{type})-1))
			{
				$globalflags[$_->{ofs}] |= GLOBALFLAG_N;
			}
		}
	}
	my %offsets_initialized = ();
	for(0..(@{$p{globals}}-1))
	{
		if($p{globals}[$_]{v}{int})
		{
			$globalflags[$_] |= GLOBALFLAG_I;
		}
	}

	my @globaltypes = (undef) x @{$p{globals}};

	my %istemp = ();
	for(0..(@{$p{globals}}-1))
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
				$globaltypes[$_] = "temp";
				++$istemp{$_};
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
	$p{temps} = \%istemp;

	print STDERR "Naming...\n";
	# globaldefs
	my @globaldefs = (undef) x @{$p{globaldefs}};
	for(@{$p{globaldefs}})
	{
		my $s = $p{getstring}->($_->{s_name});
		$_->{debugname} //= "\$" . "$s"
			if length $s;
	}
	for(@{$p{globaldefs}})
	{
		$globaldefs[$_->{ofs}] //= $_
			if defined $_->{debugname};
	}
	for(@{$p{globaldefs}})
	{
		$globaldefs[$_->{ofs}] //= $_;
	}
	for(0..(@{$p{globals}}-1))
	{
		$globaldefs[$_] //= {
			ofs => $_,
			s_name => undef,
			debugname => undef
		};
	}
	my %globaldefs = ();
	for(0..(@{(DEFAULTGLOBALS)}-1))
	{
		$globaldefs[$_] = { ofs => $_, s_name => undef, debugname => DEFAULTGLOBALS->[$_], type => undef };
		$globaltypes[$_] = 'defglobal';
	}
	for(@globaldefs)
	{
		if(defined $_->{debugname})
		{
			# already has debugname
		}
		elsif($globaltypes[$_->{ofs}] eq 'const')
		{
			$_->{debugname} = get_constant(\%p, $p{globals}[$_->{ofs}]{v});
		}
		else
		{
			$_->{debugname} = "$globaltypes[$_->{ofs}]_$_->{ofs}";
		}
		++$globaldefs{$_->{debugname}};
	}
	for(@globaldefs)
	{
		next
			if $globaldefs{$_->{debugname}} <= 1;
		#print "Not unique: $_->{debugname} at $_->{ofs}\n";
		$_->{debugname} .= "\@$_->{ofs}";
	}
	$p{globaldef_byoffset} = sub
	{
		my ($ofs) = @_;
		my $def = $globaldefs[$ofs];
		return $def;
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
	#my $checkfunc = \&disassemble_function;
	for(sort { $a->{debugname} cmp $b->{debugname} } @{$p{functions}})
	{
		$checkfunc->(\%p, $_);
	}
}

open my $fh, '<', $ARGV[0];
parse_progs $fh;
