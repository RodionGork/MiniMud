use v5.16;
use open ':std', ':encoding(UTF-8)';
use warnings;
use File::Basename;
use lib dirname(__FILE__);
require 'kernel.pl';

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
    my $cmds = meta('cmds');
    my $lookcmd = '';
    for my $c (@$cmds) {
        $lookcmd = $$c[0] if ($$c[1] eq '@look');
    }
    print "Auto executing '$lookcmd' command...\n";
    print runCmd($uid, $lookcmd) . "\n";
}

while (1) {
    my $ur = '';
    while (1) {
        my $line = <STDIN>;
        $ur .= trim($line);
        last if (substr($ur, -1) ne '\\');
        $ur = substr($ur, 0, -1) . ' ';
    }
    if ($ur eq 'quit') {
        print "ok, bye!\n";
        last;
    }
    my $resp = runCmd($uid, trim($ur));
    print "$resp\n";
}

