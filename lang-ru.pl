use v5.16;
use warnings;
use utf8;

my %ves = ('m' => '', 'f' => 'а', 'p' => 'и',
    'sm' => 'ся', 'sf' => 'ась', 'sp' => 'ись',
    'shm' => 'ёл', 'shf' => 'ла', 'shp' => 'ли',
    'zm' => '', 'zf' => 'ла', 'zp' => 'ли');

sub ruVerbEnding {
    my ($v, $flex) = @_;
    if (substr($v, length($v)-1) eq 'л') {
        return $v . $ves{$flex} if substr($v, length($v)-3) ne 'шёл';
        return substr($v, 0, length($v)-2) . $ves{'sh' . $flex};
    } elsif (substr($v, length($v)-3) eq 'лся') {
        return substr($v, 0, length($v)-2) . $ves{'s' . $flex};
    }
    return $v . $ves{'z' . $flex};
}

sub amendMsg {
    my ($msg, $flex) = @_;
    $msg =~ s/(\S+)#v/ruVerbEnding($1, $flex)/ge;
    return $msg;
}

1;
