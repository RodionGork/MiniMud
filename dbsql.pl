use v5.16;
use warnings;
use DBI;
use JSON::PP;

sub sqlite_conn {
    my $connstr = 'dbi:SQLite:uri=file:gamedata.db';
    return DBI->connect($connstr . '?mode=' . $_[0], '', '',
        {PrintError=>0, AutoCommit=>0, sqlite_unicode=>1});
}

sub sqlite_init {
    my $res = sqlite_conn('rwc') or die('DB opening failed');
    $res->do('create table kv (k text primary key, v text)');
    say 'Initializing database...';
    return $res;
}

my $db;
my $dbuser = $ENV{'DB_USER'} // '';
if ($dbuser) {
    $db = DBI->connect('dbi:mysql:' . $ENV{'DB_NAME'},
        $dbuser, $ENV{'DB_PWD'}, {AutoCommit=>0});
} else {
    $db = (sqlite_conn('rw') or sqlite_init());
}

my $json = JSON::PP->new->allow_nonref;

sub dbcommit {
    $db->commit();
}

sub kvset {
    my ($k, $v) = @_;
    if ($v ne '!del') {
        $v = $json->encode($v);
        my $n = $db->do('update kv set v=? where k=?', undef, $v, $k);
        if ($n < 1) {
            $db->do('insert into kv (k, v) values (?, ?)', undef, $k, $v);
        }
    } else {
        $db->do('delete from kv where k=?', undef, $k);
    }
}

sub kvget {
    my @res = $db->selectrow_array('select v from kv where k=?', {RaiseError=>0}, $_[0]);
    return undef unless @res;
    return $json->decode($res[0]);
}

sub kvsave {
    my %res;
    my $arr = $db->selectall_arrayref('select k, v from kv');
    for my $row (@$arr) {
        $res{$$row[0]} = $json->decode($$row[1]);
    }
    my $j = JSON::PP->new->allow_nonref->pretty;
    open(my $f, '>:encoding(UTF-8)', shift @_);
    print $f $j->encode(\%res);
    close($f)
}

sub kvload {
    open(my $f, '<:encoding(UTF-8)', shift @_);
    local $/;
    my $res = $json->decode(<$f>);
    kvset($_, $$res{$_}) for (keys %$res);
}

1;
