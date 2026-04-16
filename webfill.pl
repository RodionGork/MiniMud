use v5.16;
use open ':std', ':encoding(UTF-8)';
use warnings;
use File::Basename;
use lib dirname(__FILE__);
use HTTP::Tiny;
use Encode;
require 'kernel.pl';
require 'tokens.pl';

if (@ARGV < 1) {
    print "Please specify token as the first argument!\n";
    exit(1);
}

my $token = $ARGV[0];

my ($uid, $url, $ts) = parseToken($token);

my $http = HTTP::Tiny->new;

while (1) {
    my $ur = '';
    while (1) {
        my $line = <STDIN>;
        $line = 'quit' unless defined $line;
        $ur .= trim($line);
        last if (substr($ur, -1) ne '\\');
        $ur = substr($ur, 0, -1) . ' ';
    }
    if ($ur eq 'quit') {
        print "ok, bye!\n";
        dbcommit();
        last;
    }
    my $resp = $http->request('POST', $url, {content => $token . "\n" . encode('UTF-8', trim($ur))});
    print decode('UTF-8', $$resp{content}) . "\n";
}

