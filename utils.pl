use v5.16;
use warnings;
use JSON::PP;

sub handle { return kvop('h', @_); }

sub inspect {
    my $cmd = $_[0];
    my $j = JSON::PP->new->allow_nonref;
    if (substr($cmd, 0, 2) eq '//') {
        $j = $j->pretty;
        $cmd = substr $cmd, 1;
    }
    my @cmd = split '=', substr $cmd, 1;
    my $replace;
    if (@cmd > 1) {
        $replace = $cmd[1];
        $replace = [] if ($replace eq '[]');
        $replace = {} if ($replace eq '{}');
    }
    my @path = split '/', $cmd[0];
    my $key = shift @path;
    my $par;
    my $obj = kvget($key);
    return "No such record in storage: $key" unless ($obj || @path == 0 && defined($replace));
    my $elem = $obj;
    my $subkey = $key;
    my $parIsHash = 1;
    while (@path) {
        $subkey = shift @path;
        $par = $elem;
        $parIsHash = ref($elem) eq 'HASH';
        $elem = $parIsHash ? $$elem{$subkey} : $$elem[$subkey];
        return "No subkey: $subkey" unless (defined($elem) || @path == 0 && defined($replace));
    }
    return $j->encode($elem//"No leaf for key $subkey") unless (defined $replace);
    if ($replace ne '-') {
        if ($parIsHash) {
            $$par{$subkey} = $replace;
        } else {
            $$par[$subkey] = $replace;
        }
    } else {
        if ($parIsHash) {
            delete $$par{$subkey};
        } else {
            splice @$par, $subkey, 1;
        }
    }
    kvset($key, $obj);
    return "saved '$key': $replace";
}

sub kvop {
    my $suffix = shift @_;
    my $key = (shift @_) . '-' . $suffix;
    return @_ ? kvset($key, $_[0]) : kvget($key);
}

sub meta { return kvop('x', @_); }

sub msgs { return kvop('m', @_); }

sub numOrStr {
    my $v = $_[0];
    return ($v =~ /^\d.*/) ? ($v+0) : ($v."");
}

sub obj { return kvop('o', @_); }

sub room { return kvop('r', @_); }

sub roomstate { return kvop('rs', @_); }

sub splitAndFill {
    my ($sep, $str, $cnt) = @_;
    my @res = split($sep, $str, $cnt);
    while (@res < $cnt) {
        push @res, "";
    }
    return @res;
}

sub trim {
    $_[0] =~ s/^\s+|\s$//g;
    return $_[0];
}

sub user { return kvop('u', @_); }

sub userdata { return kvop('ud', @_); }

1;
