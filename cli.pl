use v5.16;
use warnings;
use File::Basename;
use lib dirname(__FILE__);
require 'kernel.pl';

our $autoCreateUser = 1;

if (@ARGV < 1) {
    print "Please specify Uid as a first argument!\n";
    exit(1);
}

my $uid = $ARGV[0];

if (@ARGV > 1) {
    for my $cmd (split /\;\s*/, $ARGV[1]) {
        chomp $cmd;
        print "executing: $cmd\n" . runCmd($uid, $cmd) . "\n";
    }
} else {
    print "Auto executing 'look' command...\n";
    runCmd($uid, 'look');
}

while (1) {
    my $ur = '';
    while (1) {
        my $line = <STDIN>;
        chomp $line;
        $ur .= $line;
        last if (substr($ur, -1) ne '\\');
        $ur = substr($ur, 0, -1) . ' ';
    }
    if ($ur eq 'quit') {
        print "ok, bye!\n";
        last;
    }
    chomp $ur;
    my $resp = runCmd($uid, $ur);
    print "$resp\n";
}

