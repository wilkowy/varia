# TVP - TCL Validator in Perl v1.12
# Copyright (c) 2007-2017 by wilk wilkowy
# All rights reserved.

# ToDo:
# - validate map arrays
# - problem with recognizing unused global vars...

use strict;
use warnings;
use Storable qw/store retrieve/;

die "Usage: tvp [-h] [-pf/pl -pu <tmp_file>] [-gf/gl -gu <tmp_file>] [-g <file>] [-p <file>] [-i <file>] [-d <0-5>] <file...>\n" if (@ARGV < 1);

sub DBG_NONE { return 0; } # no output
sub DBG_ERRS { return 1; } # errors
sub DBG_WARN { return 2; } # warnings
sub DBG_INFO { return 3; } # infos
sub DBG_USES { return 4; } # variables usage
sub DBG_DUMP { return 5; } # detailed dump

my @files;
my $debug = DBG_ERRS;
my $header = 0;
my $globals = 0;
my $procs = 0;
my $ignores = 0;
my %fglobal;
my %fproc;
my %fignore;
my %var;
my %proc;

my $globals_usage_state = 1;
my $procs_usage_state = 1;
my $globals_usage_file = '';
my $procs_usage_file = '';
my $globals_usage = {};
my $procs_usage = {};

my $import_all = 0;
my $import_pattern = '';

while (1) {
	my $arg = shift;
	last if (!defined($arg) || ($arg eq ''));
	my $file;
	if ($arg eq '-pf')	{ $procs_usage_state = 0;	next; }
	if ($arg eq '-pl')	{ $procs_usage_state = 2;	next; }
	if ($arg eq '-gf')	{ $globals_usage_state = 0;	next; }
	if ($arg eq '-gl')	{ $globals_usage_state = 2;	next; }
	if ($arg eq '-h')	{ $header = 1;				next; }
	if ($arg eq '-gu') {
		$globals_usage_file = shift;
		if ($globals_usage_state != 0) {
			if (-e $globals_usage_file) {
				$globals_usage = retrieve($globals_usage_file);
			}
		}
		next;
	}
	if ($arg eq '-pu') {
		$procs_usage_file = shift;
		if ($procs_usage_state != 0) {
			if (-e $procs_usage_file) {
				$procs_usage = retrieve($procs_usage_file);
			}
		}
		next;
	}
	if ($arg eq '-g') {
		$file = shift;
		open(F, $file) or die "$!: $file\n";
		while (<F>) {
			chomp;
			if (!/^ *$/ && !/^#/) {
				warn "\nduplicate (g): $_" if (exists($fglobal{$_}));
				$fglobal{$_} = 0;
				$globals_usage->{$_} = 0 if ($globals_usage_state == 0);
			}
		}
		close F;
		$globals = scalar keys %fglobal;
		next;
	}
	if ($arg eq '-p') {
		$file = shift;
		open(F, $file) or die "$!: $file\n";
		while (<F>) {
			chomp;
			if (!/^ *$/ && !/^#/) {
				warn "\nduplicate (p): $_" if (exists($fproc{$_}));
				$fproc{$_} = 0;
				$procs_usage->{$_} = 0 if ($procs_usage_state == 0);
			}
		}
		close F;
		$procs = scalar keys %fproc;
		next;
	}
	if ($arg eq '-i') {
		$file = shift;
		open(F, $file) or die "$!: $file\n";
		while (<F>) {
			chomp;
			if (!/^ *$/ && !/^#/) {
				warn "\nduplicate (i): $_" if (exists($fignore{$_}));
				$fignore{$_} = 0;
			}
		}
		close F;
		$ignores = scalar keys %fignore;
		next;
	}
	if ($arg eq '-d') {
		$debug = shift;
		$debug = DBG_NONE if (($debug < 0) || ($debug > 5));
		next;
	}
	push(@files, $arg);
}

foreach my $file (@files) {
	validate($file);
}

sub validate {
	my $fname = shift;
	#my %var;
	my $proc = '';
	my $depth = 0;

	syswrite STDOUT, "Validating $fname\n" if ($header);
	open(F, $fname) or die "$!: $fname\n";
	while (<F>) {
		chomp;
		s/\t/ /g;
		s/ +/ /g;
		s/^ //;
		s/ $//;
		next if (/^#/);
		if (!/^#/ && !/^$/) {
			$depth += tr/{/{/;
			$depth -= tr/}/}/;
			print "!$depth: $_\n" if ($debug >= DBG_DUMP);
		}
		if (($depth == 0) && ($proc ne '')) {
			print "X: leaving \"$proc\"\n" if ($debug >= DBG_USES);
			show_unused_vars($proc);
			$proc = '';
		}
		if ((/^proc +([_a-zA-Z0-9:]+?) +{ *(([^{}]+?|{ *[^{}]+? +.+? *} *)+?)? *}/) && ($proc eq '')) {
			$proc = $1;
			my $args = $2;
			if (defined($args) && ($args ne '')) {
				my @args; # undef
				my $ign = 0;
				foreach my $arg (split(/ /, $args)) {
					if ($arg =~ /}$/ && $ign == 1) {
						$ign = 0;
						next;
					}
					if ($ign == 0) {
						if ($arg =~ /^{/) {
							$arg =~ s/{//;
							$ign = 1;
						}
						push(@args, $arg);
					}
				}
				$args = join(' ', @args);
			}
			$import_all = 0;
			print "X ($.): entering \"$proc\"\n" if ($debug >= DBG_USES);
			new_proc($proc);
			feed_args($proc, $args) if (defined($args) && ($args ne ''));
		}
		if ($proc ne '') {
			if (tr/"/"/ % 2) {
				print "E ($.): odd quotes in \"$proc\"\n" if ($debug >= DBG_ERRS);
			}
			if (tr/\[/\[/ != tr/\]/\]/) {
				print "E ($.): odd square brackets in \"$proc\"\n" if ($debug >= DBG_ERRS);
			}
			#if (tr/\(/\(/ != tr/\)/\)/) {
			#	print "E ($.): odd brackets in \"$proc\"\n" if ($debug >= DBG_ERRS);
			#}
			if (/^global +(.+)/) {
				feed_vars($proc, $1);
			}
			if (/^variable +(.+)/) {
				feed_vars($proc, $1);
			}
			while (/^set +([0-9a-zA-Z_]+?)( |\([\${}0-9a-zA-Z_]+?\))/g) {
				my $var = $1;
				if (is_not_local($var)) {
					init_var($var, $.);
					use_var($var, $.);
					print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
				} else {
					if (!is_var($var)) {
						new_var($var, 'l');
					}
					init_var($var, $.);
					print "V ($var): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/[^0-9a-zA-Z_]set +([0-9a-zA-Z_]+?)( |\([0-9a-zA-Z_]+?\))/g) {
				my $var = $1;
				if (is_not_local($var)) {
					init_var($var, $.);
					use_var($var, $.);
					print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
				} else {
					if (!is_var($var)) {
						new_var($var, 'l');
					}
					init_var($var, $.);
					print "V ($var): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/upvar +#?\d+ +(.+)/g) {
				#my $data = \$[0-9a-zA-Z_]+? +([0-9a-zA-Z_]+)
				my @vars = split(/ /, $1);
				my %vars = @vars;
				while (my ($var1, $var2) = each %vars) {
					if ($var1 =~ /^\$/) {
						$var1 =~ s/^\$//;
					} else {
						print "W ($.): possible dependency \"$var1\" in \"$proc\"\n" if ($debug >= DBG_WARN);
					}
					if ($var1 eq $var2) {
						print "W ($.): possible dependency \"$var1\" to \"$var2\" in \"$proc\"\n" if ($debug >= DBG_WARN);
					}
					if (is_ref($var2)) {
						print "E ($.): redeclared reference \"$var2\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
					} else {
						if (is_var($var2)) {
							print "E ($.): redeclared reference \"$var2\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
						} else {
							new_var($var2, 'r');
							init_var($var2, $.);
						}
					}
					print "V ($var2): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/foreach +([0-9a-zA-Z_]+?) /g) {
				my $var = $1;
				new_var($var, 'l');
				init_var($var, $.);
				print "V ($var): $_\n" if ($debug >= DBG_USES);
			}
			while (/\$\{?([0-9a-zA-Z_]+)\}?/g) {
				my $var = $1;
				if (is_var($var)) {
					use_var($var, $.);
					if (is_local($var) && !is_init($var)) {
						print "E ($.): uninitialized variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
					}
				} else {
					print "E ($.): undeclared variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
				}
				print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
			}
			while (/gets +.+? +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_not_local($var)) {
					init_var($var, $.);
					use_var($var, $.);
					print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
				} else {
					new_var($var, 'l');
					init_var($var, $.);
					print "V ($var): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/binary scan +.+? +.+? +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_not_local($var)) {
					init_var($var, $.);
					use_var($var, $.);
					print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
				} else {
					new_var($var, 'l');
					init_var($var, $.);
					print "V ($var): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/regsub +.+? +.+? +.+? +.+? +([0-9a-zA-Z_]+)$/g) {
				my $var = $1;
				if (is_not_local($var)) {
					init_var($var, $.);
					use_var($var, $.);
					print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
				} else {
					new_var($var, 'l');
					init_var($var, $.);
					print "V ($var): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/l?append +([0-9a-zA-Z_]+?) /g) {
				my $var = $1;
				if (is_var($var)) {
					init_var($var, $.);
					if (is_not_local($var)) {
						use_var($var, $.);
						print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
					}
				} else {
					new_var($var, 'l');
					init_var($var, $.);
					print "V ($var): $_\n" if ($debug >= DBG_USES);
				}
			}
			while (/incr +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_var($var)) {
					init_var($var, $.);
					if (is_not_local($var)) {
						use_var($var, $.);
					}
				} else {
					print "E ($.): undeclared variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
				}
				print "U ($var): $_\n" if ($debug >= DBG_USES);
			}
			while (/info exists +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_var($var)) {
					use_var($var, $.);
				} else {
					print "E ($.): undeclared variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
				}
				print "U ($var): $_\n" if ($debug >= DBG_USES);
			}
			while (/array size +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_var($var)) {
					use_var($var, $.);
				} else {
					print "E ($.): undeclared variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
				}
				print "U ($var): $_\n" if ($debug >= DBG_USES);
			}
			while (/array names +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_var($var)) {
					use_var($var, $.);
				} else {
					print "E ($.): undeclared variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
				}
				print "U ($var): $_\n" if ($debug >= DBG_USES);
			}
			while (/unset +([0-9a-zA-Z_]+)/g) {
				my $var = $1;
				if (is_var($var)) {
					if (is_global($var) || is_ref($var)) {
						use_var($var, $.);
						print "U ($var : ".get_uses($var)."): $_\n" if ($debug >= DBG_USES);
					} else {
						delete $var{$var};
						print "D ($var): $_\n" if ($debug >= DBG_USES);
					}
				} else {
					print "E ($.): undeclared variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_ERRS);
				}
				print "V ($var): $_\n" if ($debug >= DBG_USES);
			}
		}
	}
	show_unused_vars($proc);
	close F;
}
show_unused_globs();
show_unused_procs();

sub new_var {
	my ($var, $type) = @_;
	$var{$var} = "$type 0 0 0";
	$globals_usage->{$var}++ if ($type eq 'g');
}

sub new_proc {
	my $proc = shift;
	$proc{$proc} = '0';
	if ($procs && !defined($fproc{$proc})) {
		print "W ($.): unknown procedure \"$proc\"\n" if ($debug >= DBG_WARN);
	}
	$procs_usage->{$proc}++;
}

sub get_type {
	my $var = shift;
	return '?' if (!defined($var{$var}));
	my @para = split(/ /, $var{$var});
	return $para[0];
}

sub is_init {
	my $var = shift;
	return 0 if (!defined($var{$var}));
	my @para = split(/ /, $var{$var});
	return $para[1];
}

sub get_uses {
	my $var = shift;
	return 0 if (!defined($var{$var}));
	my @para = split(/ /, $var{$var});
	return $para[2];
}

sub last_use {
	my $var = shift;
	return 0 if (!defined($var{$var}));
	my @para = split(/ /, $var{$var});
	return $para[3];
}

sub init_var {
	my ($var, $line) = @_;
	return 0 if (!defined($var{$var}));
	my @para = split(/ /, $var{$var});
	$para[1] = 1;
	$var{$var} = "$para[0] $para[1] $para[2] $line";
	#if ($para[0] eq 'g') {
		if (exists($globals_usage->{$var})) {
			$globals_usage->{$var}++;
	#	} else {
	#		print "E ($line): OMG $var\n";
		}
	#}
	return 1;
}

sub use_var {
	my ($var, $line) = @_;
	return 0 if (!defined($var{$var}));
	my @para = split(/ /, $var{$var});
	$para[2]++;
	$var{$var} = "$para[0] $para[1] $para[2] $line";
	#if ($para[0] eq 'g') {
		if (exists($globals_usage->{$var})) {
			$globals_usage->{$var}++;
	#	} else {
	#		print "E ($line): OMG $var\n";
		}
	#}
	return 1;
}

sub is_var {
	my $var = shift;
	return 1 if ((($import_all == 1) && ($var =~ /$import_pattern/)) || defined($var{$var}));
	return 0 ;
}

sub is_proc {
	my $proc = shift;
	return 1 if (defined($proc{$proc}));
	return 0;
}

sub is_local {
	my $var = shift;
	return 1 if (get_type($var) eq 'l');
	return 0;
}

sub is_global {
	my $var = shift;
	return 1 if (get_type($var) eq 'g');
	return 0;
}

sub is_arg {
	my $var = shift;
	return 1 if (get_type($var) eq 'a');
	return 0;
}

sub is_ref {
	my $var = shift;
	return 1 if (get_type($var) eq 'r');
	return 0;
}

sub is_not_local {
	my $var = shift;
	return 1 if (is_global($var) || is_arg($var) || is_ref($var));
	return 0;
}

sub feed_vars {
	my ($proc, $list) = @_;
	if ($list =~ /\{\*\}\[info globals (.+?)\]/) {
		$import_pattern = $1;
		$import_pattern =~ s/\*/.+/g;
		$import_all = 1;
		print "V (p): $1 ($import_pattern)\n" if ($debug >= DBG_USES);
	} else {
		my @vars = split(/ /, $list);
		foreach my $var (@vars) {
			if ($globals && !defined($fglobal{$var}) && (!$ignores || !defined($fignore{$var}))) {
				print "W ($.): unknown global variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_WARN);
			}
			print "W ($.): redeclared variable \"$var\" in \"$proc\"\n" if (is_var($var) && ($debug >= DBG_WARN));
			new_var($var, 'g');
			print "V (g): $var\n" if ($debug >= DBG_USES);
		}
	}
}

sub feed_args {
	my ($proc, $list) = @_;
	my @vars = split(/ /, $list);
	foreach my $var (@vars) {
		#if ($var !~ /-?[0-9]/) {
			print "E ($.): redeclared argument \"$var\" in \"$proc\"\n" if (is_arg($var) && ($debug >= DBG_ERRS));
			new_var($var, 'a');
			print "V (a): $var\n" if ($debug >= DBG_USES);
		#}
	}
}

sub show_unused_vars {
	my $proc = shift;
	foreach my $var (keys %var) {
		print "W: unused global variable \"$var\" in \"$proc\"\n" if (is_global($var) && (get_uses($var) == 0) && (!$ignores || !defined($fignore{$var})) && ($debug >= DBG_WARN));
		print "W (".last_use($var)."): unused local variable \"$var\" in \"$proc\"\n" if (is_local($var) && (get_uses($var) == 0) && ($debug >= DBG_WARN));
		print "W (".last_use($var)."): unused reference \"$var\" in \"$proc\"\n" if (is_ref($var) && (get_uses($var) == 0) && ($debug >= DBG_WARN));
		print "I: unused argument \"$var\" in \"$proc\"\n" if (is_arg($var) && (get_uses($var) == 0) && ($debug >= DBG_INFO));
		print "I (".last_use($var)."): single use local variable \"$var\" in \"$proc\"\n" if (is_local($var) && (get_uses($var) == 1) && ($debug >= DBG_INFO));
	}
	undef %var;
}

sub show_unused_globs {
	return if ($globals_usage_file eq '');
	store($globals_usage, $globals_usage_file);
	if ($globals_usage_state == 2) {
		unlink($globals_usage_file) or warn "$!: $globals_usage_file\n";
		my $was = 0;
		foreach my $glob (keys %$globals_usage) {
			if (($globals_usage->{$glob} == 0) && ($debug >= DBG_INFO)) {
				print "\n" if ($was++ == 0);
				print "I: cryptic global variable \"$glob\"\n";
			}
		}
	}
}

sub show_unused_procs {
	return if ($procs_usage_file eq '');
	store($procs_usage, $procs_usage_file);
	if ($procs_usage_state == 2) {
		unlink($procs_usage_file) or warn "$!: $procs_usage_file\n";
		my $was = 0;
		foreach my $proc (keys %$procs_usage) {
			if (($procs_usage->{$proc} == 0) && ($debug >= DBG_INFO)) {
				print "\n" if ($was++ == 0);
				print "I: cryptic procedure \"$proc\"\n";
			}
		}
	}
}
