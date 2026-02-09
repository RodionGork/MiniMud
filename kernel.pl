use v5.16;
use warnings;
use File::Basename;
use lib dirname(__FILE__);
use JSON::PP;
require ($ENV{'MUD_KV'} // 'kvdbm.pl');

our $autoCreateUser = 0;
our $wizPwd = $ENV{'MUD_WIZPWD'} // 'Pl0ugh!';
our $pathMem = 20;

my $cur;

sub action {
    my $fn = eval('\&z_' . shift @_);
    my $matches = $$cur{'matches'};
    for my $i (keys @_) {
        my $v = $_[$i];
        $_[$i] = $$matches[substr($v, 1)-1] if (substr($v, 0, 1) eq '$')
    }
    return &$fn(@_);
}

sub cmdMatchAndAct {
    my ($pat, $cmd, $act) = @_;
    my @m = ($cmd =~ /^$pat$/i);
    return '' unless (@m);
    if (substr($act, 0, 1) eq '[') {
        my ($predicate, $tail) = splitAndFill(' ', substr($act, 1), 2);
        ($tail, $act) = split /\]\s+/, $tail, 2;
        my $pfn = eval('\&z_' . $predicate);
        return '' unless (&$pfn($tail));
    }
    $$cur{'matches'} = \@m;
    my @res = ();
    my @acts = split /\s*;\s*/, $act;
    for my $a (@acts) {
        push @res, ((substr($a, 0, 1) ne '@') ? $a : action(split(/ /, substr($a, 1))));
    }
    return join "\n", @res;
}

sub hasObj {
    my ($where, $what, $state) = @_;
    my $objs = $$where{'o'};
    return -1 unless $objs;
    for my $i (keys @$objs) {
        my $obj = $$objs[$i];
        return $i if ($what eq $$obj[0] && (!defined($state) || $state eq $$obj[1]));
    }
    return -1;
}

sub initObj {
    my @arg = split /\s+#/, $_[0];
    my @descr = split /\|/, shift @arg;
    $_ = trim($_) for (@descr);
    my $res = {'d' => \@descr, 'f' => {}};
    for my $flag (@arg) {
        my ($f, $v) = split /:/, $flag;
        $$res{'f'}{$f} = numOrStr($v||1);
    }
    return $res;
}

sub initRoom {
    return {'d' => $_[0], 'w'=> []};
}

sub initUser {
    my $uid = shift @_;
    my $user = {'rm' => 'start', 'o' => [], 'seen' => []};
    user($uid, $user);
    my $handle = 'user-' . $uid;
    my $userd = {'h' => $handle, 'n' => 'Unknown'};
    userdata($uid, $userd);
    my $roomst = roomstate('start') // {};
    $$roomst{'u'}{$uid} = [$handle, time()];
    roomstate('start', $roomst);
    return $user;
}

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

sub instObj {
    my ($oid, $proto) = @_;
    my $start = $$proto{'f'}{'s'} // '';
    return '' if (!$start);
    my $state = $$proto{'f'}{'init'} // 0;
    my @places = split ',', $start;
    my $room = $places[int(rand(@places))];
    my $err = putObjInt($room, $oid, $state);
    if ($err) {
        print "$err\n";
        return '';
    }
    return $room;
}

sub kvop {
    my $suffix = shift @_;
    my $key = (shift @_) . '-' . $suffix;
    return @_ ? kvset($key, $_[0]) : kvget($key);
}

sub markSeen {
    my $rid = $_[0];
    my $seen = $$cur{'user'}{'seen'};
    my $pos = -1;
    for (my $i = 0; $i < @$seen; $i++) {
        if ($$seen[$i] eq $rid) {
            $pos = $i;
            last;
        }
    }
    splice(@$seen, $pos, 1) if ($pos >= 0);
    unshift @$seen, $rid;
    pop @$seen while (@$seen > $pathMem);
    user($$cur{'uid'}, $$cur{'user'});
}

sub meta { return kvop('x', @_); }

sub msg {
    my $key = shift @_;
    my $msg = msgs($key);
    return "msg: #$key" . (@_ ? ' [' . join(',', @_) . ']' : '') if (!$msg);
    my @msg = split /\|/, $msg;
    $msg = $msg[int(rand(@msg))];
    $msg =~ s/\$(\d)/$_[$1-1]/ge;
    return $msg;
}

sub msgs { return kvop('m', @_); }

sub newUserComes {
    my ($uid, $cmd) = @_;
    if (!$autoCreateUser) {
        my $cmds = meta('cmds');
        return msg('newuser') if ($$cmds{$cmd} ne 'Banzai! :)');
    }
    print("Auto-creating user UID=$uid\n");
    initUser($uid);
    return runCmd($uid, $cmd);
}

sub numOrStr {
    my $v = $_[0];
    return ($v =~ /^\d.*/) ? ($v+0) : ($v."");
}

sub obj { return kvop('o', @_); }

sub putObjInt {
    my ($rid, $oid, $st) = @_;
    my $roomst = roomstate($rid);
    return 'No such room' unless ($roomst);
    my $obj = obj($oid);
    return 'No such object' unless ($obj);
    push @{$$roomst{'o'}}, [$oid, $st];
    roomstate($rid, $roomst);
    return '';
}

sub room { return kvop('r', @_); }
sub roomstate { return kvop('rs', @_); }

sub runCmd {
    my ($uid, $cmd) = @_;
    my ($verb, $tail) = splitAndFill(' ', $cmd, 2);
    my $us = user($uid);
    my $ud = userdata($uid);
    return newUserComes($uid, $cmd) unless ($us);
    my $rid = $$us{'rm'};
    my $room = room($rid) // {};
    my $roomst = roomstate($rid) // {};
    $cur = {'uid'=>$uid, 'user'=>$us, 'userd'=>$ud, 'rid'=>$rid, 'room'=>$room, 'roomst'=>$roomst};
    my @cmds = @{$$room{'c'} // []};
    for my $c (@cmds) {
        my $res = cmdMatchAndAct($$c[0], $cmd, $$c[1]);
        return $res if ($res); 
    }
    @cmds = @{meta('cmds') // []};
    for my $c (@cmds) {
        my $res = cmdMatchAndAct($$c[0], $cmd, $$c[1]);
        return $res if ($res); 
    }
    if ($verb eq 'wizpwd' && $tail eq $wizPwd) {
        $$us{'wiz'} = time() + 600;
        user($uid, $us);
        return '10 min';
    }
    if (time() < ($$us{'wiz'}||0)) {
        my $firstLtr = substr $cmd, 0, 1;
        return wizCmd(substr $cmd, 1) if ($firstLtr eq '!');
        return inspect($cmd) if ($firstLtr eq '/');
    }
    return msg('nocmd');
}

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

sub wizCmd {
    my ($cmd, $tail) = splitAndFill(' ', $_[0], 2);
    my $fn = eval('\&w_' . $cmd);
    return &{$fn}($tail) if (defined &{$fn});
    return 'Unknown wiz command';
}

sub w_addcmd {
    my ($rid, $pattern, $action) = splitAndFill(' ', $_[0], 3);
    if ($rid eq '*') {
        my $cmds = meta('cmds');
        push @$cmds, [$pattern, $action];
        meta('cmds', $cmds);
        return 'command added globally';
    }
    my $room = room($rid);
    return 'No such room' unless ($room);
    push @{$$room{'c'}}, [$pattern, $action];
    room($rid, $room);
    return "command added to room #$rid";
}

sub w_addobj {
    my ($oid, $descr) = splitAndFill(' ', $_[0], 2);
    my $proto = initObj $descr;
    obj($oid, $proto);
    my $where = instObj($oid, $proto);
    if ($where) {
        $where = " and put to room #$where";
    }
    return "obj #$oid added$where";
}

sub w_addmsg {
    my ($key, $phrase) = splitAndFill(' ', $_[0], 2);
    msgs($key, $phrase);
    return "message added for #$key";
}

sub w_addroom {
    my ($rid, $descr) = splitAndFill(' ', $_[0], 2);
    room($rid, initRoom($descr));
    my $roomst = roomstate($rid);
    roomstate($rid, {}) if (!$roomst);
    return "room $rid added";
}

sub w_addway {
    my ($rid1, $dir) = splitAndFill(' ', $_[0], 2);
    my $room = room($rid1);
    return 'No source room' if (!$room);
    push @{$$room{'w'}}, $dir;
    room($rid1, $room);
    return "path from $rid1 added";
}

sub w_import {
    my $fname = $_[0];
    kvload($fname);
    my $imports = meta('import');
    unless (grep($_ eq $fname, @$imports)) {
        push @$imports, $fname;
        meta('import', $imports);
    }
    return "data file $fname loaded and added to imports";
}

sub w_load {
    my $fname = $_[0] || 'gamedata.json';
    kvload($fname);
    my $imports = meta('import');
    my $res = '';
    if ($imports) {
        for my $subfile (@$imports) {
            kvload($subfile);
            $res .= "subfile $subfile loaded\n";
        }
    }
    return $res . "data file $fname loaded";
}

sub w_putobj {
    my ($rid, $oid, $st) = splitAndFill(' ', $_[0], 3);
    $st = $st ? int($st) : 0;
    my $err = putObjInt($rid, $oid, $st);
    return $err ? $err : "obj #$oid added to room #$rid";
}

sub w_save {
    my $fname = $_[0] || 'gamedata.json';
    kvsave($fname);
    return "data file $fname saved";
}

sub z_drop {
    my $what = $_[0];
    my $user = $$cur{'user'};
    my $idx = hasObj($user, $what);
    return msg('haveno') if ($idx < 0);
    my $obj = splice @{$$user{'o'}}, $idx, 1;
    my $proto = obj($$obj[0]);
    user($$cur{'uid'}, $user);
    if (exists $$proto{'f'}{'nodrop'}) {
        my $room = instObj($what, $proto);
        return msg($room ? 'disapp' : 'disint', $what);
    } else {
        push @{$$cur{'roomst'}{'o'}}, $obj;
        roomstate($$cur{'rid'}, $$cur{'roomst'});
        return msg('drop', $what);
    }
}

sub z_get {
    my $what = $_[0];
    my $roomst = $$cur{'roomst'};
    my $idx = hasObj($roomst, $what);
    return msg('noobj') if ($idx < 0);
    my $proto = obj($what);
    return msg('noget') if (exists $$proto{'f'}{'noget'});
    my $obj = splice @{$$roomst{'o'}}, $idx, 1;
    roomstate($$cur{'rid'}, $roomst);
    push @{$$cur{'user'}{'o'}}, $obj;
    user($$cur{'uid'}, $$cur{'user'});
    return msg('get', $what);
}

sub z_grant {
    my $oid = $_[0];
    my $obj = obj($oid);
    return 'No such object' unless ($obj);
    push @{$$cur{'user'}{'o'}}, [$oid, 0];
    user ($$cur{'uid'}, $$cur{'user'});
    return 'You got ' . $oid;
}

sub z_haveObj {
    my ($obj, $state) = split /=/, $_[0], 2;
    return hasObj($$cur{'user'}, $obj, $state) >= 0;
}

sub z_look {
    my $rid = shift @_;
    my $short = @_ ? $_[0] : 0;
    my ($room, $roomst);
    if (!defined($rid)) {
        $rid = $$cur{'rid'};
        $room = $$cur{'room'};
        $roomst = $$cur{'roomst'};

    } else {
        $room = room($rid);
        $roomst = roomstate($rid);
    }
    my $descr = $$room{'d'} || "no room #$rid";
    my ($res, $long) = splitAndFill(qr/\|/, $descr, 2);
    $res .= "\n$long" if ($long && !($short && grep($_ eq $rid, @{$$cur{'user'}{'seen'}})));
    my @objdescr = map {
        obj($$_[0])->{'d'}[$$_[1]]
    } @{$$roomst{'o'} || []};
    $res .= "\n" . msg('hereare', join(', ', @objdescr)) if (@objdescr);
    markSeen($rid);
    return $res;
}

sub z_say {
    my $phrase = $_[0];
    $phrase = trim($phrase);
    my $lastchr = substr $phrase, -1;
    my $msg = $lastchr eq '?' ? 'asked' : ($lastchr eq '!' ? 'excld' : 'said');
    return msg($msg, $phrase);
}

sub z_teleport {
    my $where = $_[0];
    my $newLook = z_look($where, 1);
    my $us = $$cur{'user'};
    my $uid = $$cur{'uid'};
    $$us{'rm'} = $where;
    user($uid, $us);
    delete($$cur{'roomst'}{'u'}{$uid});
    roomstate($$cur{'rid'}, $$cur{'roomst'});
    my $rsnew = roomstate($where);
    $$rsnew{'u'}{$uid} = [$$cur{'userd'}{'h'}, time()];
    roomstate($where, $rsnew);
    return $newLook;
}

sub z_walk {
    my $dir = shift @_;
    for my $way (@{$$cur{'room'}{'w'}}) {
        my ($d0, $t0) = split / /, $way, 2;
        my ($d, $obj, $st) = splitAndFill(qr/\|/, $d0, 3);
        next unless ($d eq $dir);
        next if ($obj && hasObj($$cur{'user'}, $obj, $st) < 0 && hasObj($$cur{'room'}, $obj, $st) < 0);
        my ($tgt, $msg) = splitAndFill(qr/\|/, $t0, 2);
        $msg = z_teleport($tgt) . ($msg?"\n$msg":'') if ($tgt);
        return $msg;
    }
    return msg('noway');
}

1;
