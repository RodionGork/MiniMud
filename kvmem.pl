use v5.16;
use warnings;
use JSON::PP;

my %kv = ();

sub kvset {
    my ($k, $v) = @_;
    $kv{$k} = $v;
}

sub kvget {
    return $kv{$_[0]};
}

sub kvsave {
    my $j = JSON::PP->new->pretty;
    open(my $f, '>', shift @_);
    print $f $j->encode(\%kv);
    close($f);
}

sub kvload {
    open(my $f, '<', shift @_);
    local $/;
    my $j = JSON::PP->new;
    my $res = $j->decode(<$f>);
    @kv{keys %$res} = values %$res;
}

1;
