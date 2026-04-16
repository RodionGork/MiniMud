use v5.16;
use open ':std', ':encoding(UTF-8)';
use warnings;
use File::Basename;
use lib dirname(__FILE__);
use Term::ANSIColor ('color');
require 'kernel.pl';

my %clrs = ('H'=>'bold', 'O'=>'bright_cyan', 'E'=>'bright_yellow');

sub clr {
    my $mode = $_[0];
    my $color = $clrs{$mode}//'reset';
    return color($color);
}

sub parseColors {
    my $s = $_[0];
    $s =~ s/#:(.)/clr($1)/ge;
    $s =~ s/:#/clr('-')/ge;
    return $s;
}

if (@ARGV < 1) {
    print "Please specify Uid as the first argument!\n";
    exit(1);
}

my $uid = $ARGV[0];

if (@ARGV > 1) {
    for my $cmd (split /\;\s*/, $ARGV[1]) {
        chomp $cmd;
        print "executing: $cmd\n" . parseColors(runCmd($uid, $cmd)) . "\n";
    }
} else {
    my $cmds = meta('cmds');
    my $lookcmd = '';
    for my $c (@$cmds) {
        $lookcmd = $$c[0] if ($$c[1] eq '@look');
    }
    print "Auto executing '$lookcmd' command...\n";
    print parseColors(runCmd($uid, $lookcmd)) . "\n";
}

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
    my $resp = runCmd($uid, trim($ur));
    print parseColors($resp) . "\n";
}

