use v5.16;
use open ':std', ':encoding(UTF-8)';
use warnings;
use File::Basename;
use lib dirname(__FILE__);
use HTTP::Tiny;
use Encode;
require 'kernel.pl';
require 'tokens.pl';

if (@ARGV < 2) {
    print "Please specify token as the first argument, wizpwd as the second and filename as the third!\n";
    exit(1);
}

my $token = $ARGV[0];
my $wizpwd = $ARGV[1];
my $file = $ARGV[2];

my ($uid, $url, $ts) = parseToken($token);

my $http = HTTP::Tiny->new;

open(my $f, '<', $file);
my @cmds = <$f>;
close($f);
@cmds = grep(!/^(?:;.*|\s*)$/, @cmds);
unshift @cmds, "wizpwd $wizpwd";
unshift @cmds, "ready";

for (my $i = 0; $i < @cmds; $i++) {
    my $cmd = trim($cmds[$i]);
    while ($i+1 < @cmds && $cmds[$i+1] =~ /^\s/) {
        $cmd .= ' ' . trim($cmds[++$i]);
    }
    my $resp = $http->request('POST', $url, {content => $token . "\n" . encode('UTF-8', trim($cmd))});
    print decode('UTF-8', $$resp{content}) . "\n";
}
print "ok, bye!\n";
dbcommit();

