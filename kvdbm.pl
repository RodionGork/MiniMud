use v5.16;
use warnings;
use JSON::PP;
use SDBM_File;
use Fcntl;

my $json = JSON::PP->new->allow_nonref;
tie(my %kv, 'SDBM_File', 'gamedata.sdbm', O_RDWR|O_CREAT, 0640) or die('no sdbm');

sub kvset {
    my ($k, $v) = @_;
    $kv{$k} = $json->encode($v);
}

sub kvget {
    my $val = $kv{$_[0]};
    return $val unless (defined $val);
    return $json->decode($val);
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
    my $res = $json->decode(<$f>);
    $kv{$_} = $json->encode($$res{$_}) for (keys %$res);
    #for my $k (keys %$res) {
    #    print "$k...\n";
    #    my $v = $$res{$k};
    #    $kv{$k} = $json->encode($v);
    #}
}

1;
