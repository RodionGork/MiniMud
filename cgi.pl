use v5.16;
use warnings;
use File::Basename;
use lib dirname(__FILE__);
require 'kernel.pl';

our $autoCreateUser = 1;

my $uid = <>;
chomp $uid;
my $cmd = <>;
chomp $cmd;

print "Content-Type: text/plain\r\n\r\n";
print runCmd($uid, $cmd);

