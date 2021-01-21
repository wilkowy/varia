use strict;
use warnings;

sub set_perms {
	my $dir = shift;
	opendir(my $dh, $dir) or die $!;
	while(my $entry = readdir($dh)) {
		next if $entry =~ /^\.\.?$/;
		if (-d "$dir/$entry") {
			#print "d: $dir/$entry\n";
			set_perms("$dir/$entry");
			chmod(0701, "$dir/$entry");
		} else {
			chmod(0604, "$dir/$entry");
			#print "f: $dir/$entry\n";
		}
	}
	closedir($dh);
}

set_perms('.');
