use strict;
use warnings;

my %palgo = (
		1 => 'RSA',
		2 => 'RSA_E',
		3 => 'RSA_S',
		16 => 'ELG/Elgamal_E',
		17 => 'DSA',
		18 => 'ECDH',
		19 => 'ECDSA',
		20 => 'Elgamal',
		22 => 'EDDSA',
	);
my %salgo = (
		0 => 'none',
		1 => 'IDEA',
		2 => '3DES',
		3 => 'CAST5',
		4 => 'BLOWFISH',
		7 => 'AES',
		8 => 'AES192',
		9 => 'AES256',
		10 => 'TWOFISH',
		11 => 'CAMELLIA128',
		12 => 'CAMELLIA192',
		13 => 'CAMELLIA256',
		110 => 'dummy',
	);
my %dalgo = (
		1 => 'MD5',
		2 => 'SHA1',
		3 => 'RIPEMD160',
		8 => 'SHA256',
		9 => 'SHA384',
		10 => 'SHA512',
		11 => 'SHA224',
	);
my %zalgo = (
		0 => 'Uncompressed',
		1 => 'ZIP',
		2 => 'ZLIB',
		3 => 'BZIP2',
	);

while (<>) {
	s/expires 0/expires never/;
	s/digest algo (\d+)/$dalgo{$1}/;
	s/hash: (\d+)/$dalgo{$1}/;
	s/algo (\d+)/$palgo{$1}/;
	s/algo: (\d+)/$salgo{$1}/;
	if (/\(pref-sym-algos: ((\d+ ?)+)\)/) {
		my @a = split(/ /, $1);
		foreach my $a (@a) { $a = $salgo{$a}; }
		$a = join(' ', @a);
		s/\(pref-sym-algos: (\d+ ?)+\)/(pref-sym-algos: $a)/;
	}
	if (/\(pref-hash-algos: ((\d+ ?)+)\)/) {
		my @a = split(/ /, $1);
		foreach my $a (@a) { $a = $dalgo{$a}; }
		$a = join(' ', @a);
		s/\(pref-hash-algos: (\d+ ?)+\)/(pref-sym-algos: $a)/;
	}
	if (/\(pref-zip-algos: ((\d+ ?)+)\)/) {
		my @a = split(/ /, $1);
		foreach my $a (@a) { $a = $zalgo{$a}; }
		$a = join(' ', @a);
		s/\(pref-zip-algos: (\d+ ?)+\)/(pref-sym-algos: $a)/;
	}
	if (/\(key flags: ([0-9a-fA-F]{2})\)/) {
		my @a;
		push(@a, 'Sign') if (hex($1) & 1);
		push(@a, 'Encrypt') if (hex($1) & 2);
		push(@a, 'Certify') if (hex($1) & 4);
		push(@a, 'Authenticate') if (hex($1) & 8);
		my $a = join(' ', @a);
		s/\(key flags: ([0-9a-fA-F]{2})\)/(key flags: $a)/;
	}
	print;
}
