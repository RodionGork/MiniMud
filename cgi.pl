use v5.16;
use warnings;
use open ':std', ':encoding(UTF-8)';
use File::Basename;
use lib dirname(__FILE__);
require 'kernel.pl';
require 'tokens.pl';

my $tkn = <>;
chomp $tkn;
my ($uid, $srv, $ts) = parseToken($tkn);

my $cmd = <>;
chomp $cmd;

print "Content-Type: text/plain; charset=utf-8\r\n\r\n";

if ($uid eq '') {
    print '!err Something bad happened to your token, perhaps re-login :(';
} elsif ($ts + 86400 < time()) {
    print '!err Token expired, please re-login';
} else {
    print runCmd($uid, $cmd);
    dbcommit();
}
