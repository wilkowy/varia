# TVP - TCL Validator in Perl v1.9
# Copyright (c) 2007-2016 by wilk wilkowy
# All rights reserved.

# ToDo: validate map arrays

use strict;
use warnings;

die "Usage: tvp [-h] [-g <file>] [-p <file>] [-i <file>] [-d <0-5>] <file...>\n" if (@ARGV < 1);

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

my $import_all = 0;
my $import_pattern = '';

while (1) {
	my $arg = shift;
	last if (!defined($arg) || ($arg eq ''));
	my $file;
	if ($arg eq '-h') {
		$header = 1;
		next;
	}
	if ($arg eq '-g') {
		$file = shift;
		open(F, $file) or die "$!: $file\n";
		while (<F>) {
			chomp;
			$fglobal{$_} = 0 if (!/^ *$/ && !/^#/);
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
			$fproc{$_} = 0 if (!/^ *$/ && !/^#/);
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
			$fignore{$_} = 0 if (!/^ *$/ && !/^#/);
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
	#my %var;
	my $proc = '';
	my $depth = 0;

	syswrite STDOUT, "Validating $_[0]\n" if ($header);
	open(F, $_[0]) or die "$!: $_[0]\n";
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
#show_unused_globs();
#show_unused_procs();

sub new_var {
	$var{$_[0]} = "$_[1] 0 0 0";
}

sub new_proc {
	my $proc = $_[0];
	$proc{$proc} = '0';
	if ($procs && !defined($fproc{$proc})) {
		print "W ($.): unknown procedure \"$proc\"\n" if ($debug >= DBG_WARN);
	}
}

sub get_type {
	return '?' if (!defined($var{$_[0]}));
	my @para = split(/ /, $var{$_[0]});
	return $para[0];
}

sub is_init {
	return 0 if (!defined($var{$_[0]}));
	my @para = split(/ /, $var{$_[0]});
	return $para[1];
}

sub get_uses {
	return 0 if (!defined($var{$_[0]}));
	my @para = split(/ /, $var{$_[0]});
	return $para[2];
}

sub last_use {
	return 0 if (!defined($var{$_[0]}));
	my @para = split(/ /, $var{$_[0]});
	return $para[3];
}

sub init_var {
	return 0 if (!defined($var{$_[0]}));
	my @para = split(/ /, $var{$_[0]});
	$para[1] = 1;
	$var{$_[0]} = "$para[0] $para[1] $para[2] $_[1]";
	return 1;
}

sub use_var {
	return 0 if (!defined($var{$_[0]}));
	my @para = split(/ /, $var{$_[0]});
	$para[2]++;
	$var{$_[0]} = "$para[0] $para[1] $para[2] $_[1]";
	return 1;
}

sub is_var {
	return 1 if ((($import_all == 1) && ($_[0] =~ /$import_pattern/)) || defined($var{$_[0]}));
	return 0 ;
}

sub is_proc {
	return 1 if (defined($proc{$_[0]}));
	return 0;
}

sub is_local {
	return 1 if (get_type($_[0]) eq 'l');
	return 0;
}

sub is_global {
	return 1 if (get_type($_[0]) eq 'g');
	return 0;
}

sub is_arg {
	return 1 if (get_type($_[0]) eq 'a');
	return 0;
}

sub is_ref {
	return 1 if (get_type($_[0]) eq 'r');
	return 0;
}

sub is_not_local {
	return 1 if (is_global($_[0]) || is_arg($_[0]) || is_ref($_[0]));
	return 0;
}

sub feed_vars {
	my $proc = $_[0];
	if ($_[1] =~ /\{\*\}\[info globals (.+?)\]/) {
		$import_pattern = $1;
		$import_pattern =~ s/\*/.+/g;
		$import_all = 1;
		print "V (p): $1 ($import_pattern)\n" if ($debug >= DBG_USES);
	} else {
		my @vars = split(/ /, $_[1]);
		foreach my $var (@vars) {
			if ($globals && !defined($fglobal{$var}) && !$ignores && !defined($fignore{$var})) {
				print "W ($.): unknown global variable \"$var\" in \"$proc\"\n" if ($debug >= DBG_WARN);
			}
			print "W ($.): redeclared variable \"$var\" in \"$proc\"\n" if (is_var($var) && ($debug >= DBG_WARN));
			new_var($var, 'g');
			print "V (g): $var\n" if ($debug >= DBG_USES);
		}
	}
}

sub feed_args {
	my $proc = $_[0];
	my @vars = split(/ /, $_[1]);
	foreach my $var (@vars) {
		#if ($var !~ /-?[0-9]/) {
			print "E ($.): redeclared argument \"$var\" in \"$proc\"\n" if (is_arg($var) && ($debug >= DBG_ERRS));
			new_var($var, 'a');
			print "V (a): $var\n" if ($debug >= DBG_USES);
		#}
	}
}

sub show_unused_vars {
	my $proc = $_[0];
	foreach my $var (keys %var) {
		print "W: unused global variable \"$var\" in \"$proc\"\n" if (is_global($var) && (get_uses($var) == 0) && !$ignores && !defined($fignore{$var}) && ($debug >= DBG_WARN));
		print "W (".last_use($var)."): unused local variable \"$var\" in \"$proc\"\n" if (is_local($var) && (get_uses($var) == 0) && ($debug >= DBG_WARN));
		print "W (".last_use($var)."): unused reference \"$var\" in \"$proc\"\n" if (is_ref($var) && (get_uses($var) == 0) && ($debug >= DBG_WARN));
		print "I: unused argument \"$var\" in \"$proc\"\n" if (is_arg($var) && (get_uses($var) == 0) && ($debug >= DBG_INFO));
		print "I (".last_use($var)."): once used local variable \"$var\" in \"$proc\"\n" if (is_local($var) && (get_uses($var) == 1) && ($debug >= DBG_INFO));
	}
	undef %var;
}

sub show_unused_globs {
	foreach my $glob (keys %fglobal) {
		print "I: cryptic global variable \"$glob\"\n" if (!exists($var{$glob}) && ($debug >= DBG_INFO));
	}
}

sub show_unused_procs {
	foreach my $proc (keys %fproc) {
		print "I: cryptic procedure \"$proc\"\n" if (!exists($proc{$proc}) && ($debug >= DBG_INFO));
	}
}
