use v5.16;
use warnings;
use File::Basename;
use lib dirname(__FILE__);
require 'kernel.pl';
require 'tokens.pl';

my $tkn = <>;
chomp $tkn;
my ($uid, $srv, $ts) = parseToken($tkn);

my $cmd = <>;
chomp $cmd;

print "Content-Type: text/plain\r\n\r\n";

if ($uid ne '') {
    print runCmd($uid, $cmd);
} else {
    print 'Something bad happened to your token, perhaps re-login :(';
}
