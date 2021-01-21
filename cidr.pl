# CIDR calculator

use strict;
use warnings;

# TODO:
# - ipv6 cidr

sub usage {
	die <<'DIE'
Usage:
  cidr.pl -v <ip>
  cidr.pl <ip>
  cidr.pl <int>
  cidr.pl x<hex>
  cidr.pl <ip>/<cidr>
  cidr.pl <ip>/<mask>
  cidr.pl <ip> <ip>
  cidr.pl <ip>-<ip>
  cidr.pl <ip> - <ip>
DIE
}

sub validip {
	my $ip = shift;
	return 0 if (!defined($ip) || ($ip eq ''));
	if (index($ip, ':') != -1) { # IPv6
		return 0 if ((split(/::/, $ip) > 2) || ($ip =~ /:{3,}/));
		my @hextets = split(/:/, $ip);
		return 0 if (@hextets > 8);
		# TODO: expand ::
		return 0 if (@hextets != 8);
		foreach my $hextet (@hextets) {
			return 0 if ((substr($hextet, 0, 1) eq '0') && (length($hextet) > 1));
			return 0 if ($hextet =~ /[^0-9a-f]/);
			return 0 if ((hex($hextet) < 0) || (hex($hextet) > 0xffff));
		}
# TODO:
# *  Leading zeros MUST be suppressed.
#    For example, 2001:0db8::0001 is not acceptable and must be represented as 2001:db8::1
# *  The use of the symbol "::" MUST be used to its maximum capability.
#    For example, 2001:db8:0:0:0:0:2:1 must be shortened to 2001:db8::2:1.
# *  The symbol "::" MUST NOT be used to shorten just one 16-bit 0 field.
#    For example, the representation 2001:db8:0:1:1:1:1:1 is correct, but 2001:db8::1:1:1:1:1 is not correct.
# done *  The characters "a", "b", "c", "d", "e", and "f" in an IPv6 address MUST be represented in lowercase.
	} else { # IPv4
		my @octets = split(/\./, $ip);
		return 0 if (@octets != 4);
		return 0 if (grep { ($_ !~ /^\d+$/) || ($_ > 255) || ($_ < 0) } @octets);
	}
	return 1;
}

sub longip {
	my $ip = shift;
	return '' if (!defined($ip) || ($ip eq ''));
	return '' if (index($ip, ':') != -1); # TODO: no ipv6 yet
	my @octets = split(/\./, $ip);
	if (@octets == 1) { # int
		return '' if ($ip !~ /^\d+$/ || $ip > 0xffffffff); # 4294967295
		my $hexip = sprintf('%08x', $ip);
		return sprintf('%d.%d.%d.%d',
						hex(substr($hexip, 0, 2)),
						hex(substr($hexip, 2, 2)),
						hex(substr($hexip, 4, 2)),
						hex(substr($hexip, 6, 2)));
		# return inet_ntoa(pack('N*', $ip));
	} elsif (validip($ip)) { # IPv4
		return ((($octets[0] * 256) + $octets[1]) * 256 + $octets[2]) * 256 + $octets[3];
		# return unpack('l*', pack('l*', unpack('N*', inet_aton($ip))));
	} else {
		return '';
	}
}

sub cidr2range {
	my ($ip, $cidr) = @_;
	my $long_mask = (0xffffffff << (32 - $cidr)) & 0xffffffff;
	my $long_ip_l = longip($ip) & $long_mask;
	my $long_ip_h = $long_ip_l | (~$long_mask & 0xffffffff);
	return (longip($long_ip_l), longip($long_ip_h), longip($long_mask), $long_ip_l, $long_ip_h);
}

sub range2cidr {
	my ($ip_l, $ip_h) = @_;
	my ($long_ip_l, $long_ip_h) = (longip($ip_l), longip($ip_h));
	my ($tmp_long_ip_l, $tmp_long_ip_h) = ($long_ip_l, $long_ip_h);
	my $cidr = 0;
	while (($tmp_long_ip_l & 0x80000000) == ($tmp_long_ip_h & 0x80000000)) {
		$cidr++;
		last if ($cidr == 32);
		$tmp_long_ip_l <<= 1;
		$tmp_long_ip_h <<= 1;
	}
	return ($ip_l, $cidr, $long_ip_l, $long_ip_h);
}

sub mask2range {
	my ($ip, $mask) = @_;
	my $long_ip_l = longip($ip) & longip($mask);
	my $long_ip_h = $long_ip_l | (~longip($mask) & 0xffffffff);
	my $diff = $long_ip_h - $long_ip_l;
	my $cidr = 0;
	while ($diff > 0) {
		$cidr++;
		$diff >>= 1;
	}
	return (longip($long_ip_l), longip($long_ip_h), 32 - $cidr, $long_ip_l, $long_ip_h);
}

usage() if (@ARGV < 1);

my ($arg1, $arg2, $rest) = @ARGV;

if ((@ARGV == 2) && ($arg1 eq '-v')) {
	print(('invalid IP', 'valid IP')[validip($arg2)] . "\n");
	exit;
}

if ((@ARGV == 1) && (index($arg1, '-') == -1) && (index($arg1, '/') == -1)) { # single ip/int/hex
	if ($arg1 =~ /^0?x([0-9a-f]{8})$/i) { # hex
		#my $hexip = uc($arg1 =~ s/^0?x//ir);
		my $hexip = uc($1);
		printf("hex:\t%s\n", $hexip);
		printf("int:\t%s\n", hex $hexip);
		printf("IPv4:\t%s\n", longip(hex $hexip));
		#printf("IPv4:\t%d.%d.%d.%d\n", hex(substr($hexip, 0, 2)), hex(substr($hexip, 2, 2)), hex(substr($hexip, 4, 2)), hex(substr($hexip, 6, 2)));
	} elsif ($arg1 =~ /^\d+$/) { # int
		my $ip = longip($arg1);
		die "invalid argument ($arg1)\n" if ($ip eq '');
		printf("int:\t%d\n", $arg1);
		printf("hex:\t%08X\n", $arg1);
		printf("IPv4:\t%s\n", $ip);
	} else { # IPv4
		die "invalid IP ($arg1)\n" if (!validip($arg1));
		my $longip = longip($arg1);
		printf("IPv4:\t%s\n", $arg1);
		printf("int:\t%d\n", $longip);
		printf("hex:\t%08X\n", $longip);
		#my @octets = split(/\./, $arg1);
		#printf("hex:\t%02X%02X%02X%02X\n", $octets[0], $octets[1], $octets[2], $octets[3]);
	}
	exit;
}

$arg2 = $rest if (defined($arg2) && ($arg2 eq '-')); # ip1 - ip2 (optional "-")
if (index($arg1, '-') != -1) { # ip1-ip2
	($arg1, $arg2) = split(/\-/, $arg1);
}

if (index($arg1, '/') != -1) { # ip/cidr OR ip/mask
	my ($ip, $cidr) = split(/\//, $arg1);
	die "invalid IP ($ip)\n" if (!validip($ip));
	if ($cidr =~ /^\d+$/) { # ip/cidr
		die "invalid CIDR ($cidr)\n" if (($cidr < 0) || ($cidr > 32));
		printf("CIDR:\t\t%s/%d\n", $ip, $cidr);
		my ($ip_l, $ip_h, $mask) = cidr2range($ip, $cidr);
		printf("IP range:\t%s - %s\n", $ip_l, $ip_h);
		printf("IP mask:\t%s/%s\n", $ip, $mask);
	} else { # ip/mask
		my $mask = $cidr;
		die "invalid IP mask ($mask)\n" if (!validip($mask));
		printf("IP mask:\t%s/%s\n", $ip, $mask);
		my ($ip_l, $ip_h, $cidr, $long_ip_l, $long_ip_h) = mask2range($ip, $mask);
		my ($ip2_l, $ip2_h, undef, $long_ip2_l, $long_ip2_h) = cidr2range($ip, $cidr);
		if (($long_ip_l == $long_ip2_l) && ($long_ip_h == $long_ip2_h)) {
			printf("IP range:\t%s - %s\n", $ip_l, $ip_h);
			printf("CIDR:\t\t%s/%d\n", $ip_l, $cidr);
		} else {
			printf("IP range (*):\t%s - %s\n", $ip_l, $ip_h);
			printf("CIDR:\t\t%s/%d\n", $ip_l, $cidr);
			printf("IP range:\t%s - %s\n", $ip2_l, $ip2_h);
		}
	}
} else { # ip1 ip2
	my ($ip1, $ip2) = ($arg1, $arg2);
	die "invalid IP ($ip1)\n" if (!validip($ip1));
	die "invalid IP ($ip2)\n" if (!validip($ip2));
	printf("IP range:\t%s - %s\n", $ip1, $ip2);
	my (undef, $cidr, $long_ip_l, $long_ip_h) = range2cidr($ip1, $ip2);
	my ($ip2_l, $ip2_h, $mask, $long_ip2_l, $long_ip2_h) = cidr2range($ip1, $cidr);
	if (($long_ip_l == $long_ip2_l) && ($long_ip_h == $long_ip2_h)) {
		printf("CIDR:\t\t%s/%d\n", $ip2_l, $cidr);
		printf("IP mask:\t%s/%s\n", $ip2_l, $mask);
	} else {
		printf("CIDR (*):\t%s/%d\n", $ip2_l, $cidr);
		printf("IP range:\t%s - %s\n", $ip2_l, $ip2_h);
		printf("IP mask:\t%s/%s\n", $ip2_l, $mask);
	}
}
