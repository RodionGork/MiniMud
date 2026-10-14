use v5.16;
use open ':std', ':encoding(UTF-8)';
use warnings;
use File::Basename;
use lib dirname(__FILE__);
use Term::ANSIColor ('color');
require 'kernel.pl';

my %clrs = ('H'=>'bold', 'O'=>'bright_cyan', 'E'=>'bright_yellow',
    'U'=>'bright_red', 'g'=>'green', 'r'=>'red', 'c'=>'cyan', 'y'=>'yellow',
    'm'=>'magenta', 'b'=>'blue', 'p'=>'bright_red', 'v'=>'bright_blue',
    'x'=>'bright_yellow', 'w'=>'bold');

sub clr {
    my $mode = $_[0];
    my $color = $clrs{$mode}//'reset';
    return color($color);
}

sub parseColors {
    my $s = $_[0];
    $s =~ s/%:(.)/clr($1)/ge;
    $s =~ s/:%/clr('-')/ge;
    return $s;
}

if (@ARGV < 1) {
    print "Please specify Uid as the first argument!\n";
    exit(1);
}

my $uid = $ARGV[0];

if (@ARGV > 1) {
    my @cmds = split /\;\s*/, $ARGV[1];
    my ($file) = $cmds[-1] =~ /load\s+(\S+\.txt)/;
    if ($file) {
        open(my $f, '<', $file);
        my @file = <$f>;
        close($f);
        pop @cmds;
        push @cmds, grep(!/^(?:;.*|\s*)$/, @file);
    }
    for (my $i = 0; $i < @cmds; $i++) {
        my $cmd = trim($cmds[$i]);
        while ($i+1 < @cmds && $cmds[$i+1] =~ /^\s/) {
            $cmd .= ' ' . trim($cmds[++$i]);
        }
        print parseColors(runCmd($uid, $cmd)) . "\n";
    }
    dbcommit();
    print "(done)\n";
    exit;
}

my $cmds = meta('cmds');
my $lookcmd = '';
for my $c (@$cmds) {
    $lookcmd = $$c[0] if ($$c[1] eq '@look');
}
print "Auto executing '$lookcmd' command...\n";
print parseColors(runCmd($uid, $lookcmd)) . "\n";

while (1) {
    my $ur = '';
    while (1) {
        my $line = <STDIN>;
        $line = 'quit' unless defined $line;
        $line = trim($line);
        next if !$line || substr($line, 0, 1) eq ';';
        $ur .= $line;
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

