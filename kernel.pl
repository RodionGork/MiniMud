use v5.16;
use warnings;
use File::Basename;
use lib dirname(__FILE__);
require 'dbsql.pl';
require 'utils.pl';
require 'wizard.pl';

my $lang = $ENV{'MUD_LANG'} // '';
if ($lang) {
    require "lang-$lang.pl";
} else {
    $lang = 'en';
}

our $wizPwd = $ENV{'MUD_WIZPWD'} // 'Pl0ugh!';
our $pathMem = 20;
our $goSleepTime = 90;
our $goExpiredTime = 180;
our $maxObjInHands = 2;

my $cur;

sub action {
    my $fn = eval('\&z_' . shift @_);
    my $matches = $$cur{'matches'};
    for my $i (keys @_) {
        my $v = $_[$i];
        $_[$i] = $$matches[substr($v, 1)-1] if ($v =~ /^\$\d/);
    }
    updateUserTimestamp();
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
        if (substr($a, 0, 1) eq '@') {
            my @params = ();
            my ($act, $params) = split / /, substr($a, 1), 2;
            if (defined $params) {
                @params = substr($params, 0, 1) ne '!' ? split(/ /, $params) : (substr $params, 1);
            }
            my @aa = action($act, @params);
            push @res, $aa[0];
            last if @aa > 1 && $aa[1];
        } else {
            push @res, $a;
        }
    }
    return join "\n", @res;
}

sub hasObj {
    my ($where, $what, $state) = @_;
    my $objs = $$where{'o'};
    return -1 unless $objs;
    for my $i (keys @$objs) {
        my $obj = $$objs[$i];
        return $i if (objNameMatch($what, 1, $$obj[0], $$obj[3]) && (!defined($state) || $state eq $$obj[1]));
    }
    return -1;
}

sub hereUser {
    my $target = $_[0];
    my $case = @_ > 1 ? $_[1] : 0;
    my $users = $$cur{'roomst'}{'u'};
    for my $uid (keys %$users) {
        my $val = $$users{$uid};
        my $name = $case ? ((split / /, $$val[2])[$case-1]) : $$val[0];
        return $uid, $name if ($name eq $target)
    }
    return 0, '';
}

sub initObj {
    my ($text, $synonyms) = @_;
    my @arg = split /\s+#/, $text;
    my @descr = split /\|/, shift @arg;
    $_ = trim($_) for (@descr);
    my $res = {'d' => \@descr, 'f' => {}, 's' => $synonyms};
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
    my $user = {'rm' => 'start', 'o' => [], 'seen' => [], 'ev' => []};
    user($uid, $user);
    my $handle = randomHandle();
    my $userd = {'h' => $handle, 'n' => 'Unknown', 'g' => 'f'};
    userdata($uid, $userd);
    handle($handle, $uid);
    my $roomst = roomstate('start') // {};
    $$roomst{'u'}{$uid} = [$handle, 0, $$userd{'n'}];
    roomstate('start', $roomst);
    return $user;
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

sub isAwake {
    return $$cur{'ts'} - $_[0] <= $goSleepTime;
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

sub msg {
    my $key = shift @_;
    my $msg = $key ? msgs($key) : shift @_;
    return "msg: #$key" . (@_ ? ' [' . join(',', @_) . ']' : '') if (!$msg);
    my @msg = split /\|/, $msg;
    $msg = $msg[int(rand(@msg))];
    $msg =~ s/\$(\d)/$_[$1-1]/ge;
    if (index($msg, '$u') >= 0) {
        my $person = $$cur{'userd'}{'h'};
        my $msg1 = $msg;
        $msg1 =~ s/\$u/$person/;
        $person = you();
        $msg =~ s/\$u/$person/;
        if (defined(&amendMsg)) {
            $msg = amendMsg($msg, 'p');
            $msg1 = amendMsg($msg1, $$cur{'userd'}{'g'});
        }
        my ($whomid, $msg2) = ('', '');
        if (index($msg, '$v') >= 0) {
            my $whom = pop @_;
            $whomid = pop @_;
            $msg =~ s/\$v\d/$whom/;
            $msg2 = $msg1;
            $msg1 =~ s/\$v\d/$whom/;
            $msg2 =~ s/\$v(\d)/you($1)/e;
        }
        notify($msg1, $whomid, $msg2);
    }
    return $msg;
}

sub newUserComes {
    my ($uid, $cmd) = @_;
    my $cmds = meta('cmds') // [];
    if (!@{$cmds}) {
        w_import("cmds-$lang.json");
        w_import("msgs-$lang.json");
        $cmds = meta('cmds');
    }
    for my $c (@$cmds) {
        my @m = ($cmd =~ /^$$c[0]$/i);
        if (@m && $$c[1] eq 'Banzai! :)') {
            initUser($uid);
            my $ud = userdata($uid);
            return msg('greetnew');
        }
    }
    return msg('newuser');
}

sub notify {
    my ($msg, $whomid, $msg2) = @_;
    my $uid = $$cur{'uid'};
    my $rs = $$cur{'roomst'};
    my $users = $$rs{'u'};
    for my $id (keys %$users) {
        my $urec = $$users{$id};
        next if $id eq $uid;
        next unless isAwake($$urec[1]);
        my $other = user($id);
        push @{$$other{'ev'}}, ($id ne $whomid ? $msg : $msg2);
        user($id, $other);
    }
}

sub objFromRoom {
    my $what = $_[0];
    my $roomst = $$cur{'roomst'};
    my $idx = hasObj($roomst, $what);
    return msg('noobj') if ($idx < 0);
    my $proto = obj($what);
    return msg('noget') if (exists $$proto{'f'}{'noget'});
    my $obj = splice @{$$roomst{'o'}}, $idx, 1;
    return '', $what, $obj, $proto;
}

sub objFromUser {
    my $what = $_[0];
    my $user = $$cur{'user'};
    my $idx = hasObj($user, $what);
    return msg('haveno', $what) if ($idx < 0);
    my $obj = splice @{$$user{'o'}}, $idx, 1;
    my $proto = obj($$obj[0]);
    return '', $what, $obj, $proto;
}

sub objNameMatch {
    my ($name, $flex, $oid, $syn) = @_;
    return 1 if $name eq $oid;
    for my $s (split /\,/, $syn) {
        my @cases = split /\|/, $s;
        return 1 if $name eq $cases[$flex < @cases ? $flex : 0];
    }
    return 0;
}

sub putObjInt {
    my ($rid, $oid, $st) = @_;
    my $roomst = roomstate($rid);
    return 'No such room' unless ($roomst);
    my $obj = obj($oid);
    return 'No such object' unless ($obj);
    push @{$$roomst{'o'}}, [$oid, $st, $$obj{'d'}[$st], $$obj{'s'}];
    roomstate($rid, $roomst);
    return '';
}

sub randomHandle {
    my @pref = ('zaya', 'ptec', 'pchol', 'wowk', 'lissa', 'luan', 'kyrin');
    my $suff = 100;
    while (1) {
        my $h = $pref[int(rand(@pref))] . '-' . int(rand($suff));
        return $h unless handle($h);
        $suff *= 10;
    }
}

sub reportEvents {
    my ($uid, $user) = @_;
    my $res = join "\n", @{$$user{'ev'}};
    $$user{'ev'} = [];
    user($uid, $user);
    return $res;
}

sub runCmd {
    my ($uid, $cmd) = @_;
    my ($verb, $tail) = splitAndFill(' ', $cmd, 2);
    my $us = user($uid);
    return newUserComes($uid, $cmd) unless ($us);
    my $events = reportEvents($uid, $us);
    return $events if $cmd eq 'chkevt';
    $events .= "\n" if $events ne '';
    my $ud = userdata($uid);
    my $rid = $$us{'rm'};
    my $room = room($rid) // {};
    my $roomst = roomstate($rid) // {};
    $cur = {'uid'=>$uid, 'user'=>$us, 'userd'=>$ud, 'rid'=>$rid, 'room'=>$room, 'roomst'=>$roomst, 'ts'=>time()};
    my @cmds = @{$$room{'c'} // []};
    for my $c (@cmds) {
        my $res = cmdMatchAndAct($$c[0], $cmd, $$c[1]);
        return $events . $res if ($res);
    }
    @cmds = @{meta('cmds') // []};
    for my $c (@cmds) {
        my $res = cmdMatchAndAct($$c[0], $cmd, $$c[1]);
        return $events . $res if ($res);
    }
    if ($verb eq 'wizpwd' && $tail eq $wizPwd) {
        $$us{'wiz'} = $$cur{'ts'} + 600;
        user($uid, $us);
        return '10 min';
    }
    if ($$cur{'ts'} < ($$us{'wiz'}||0)) {
        my $firstLtr = substr $cmd, 0, 1;
        return wizCmd(substr $cmd, 1) if ($firstLtr eq '!');
        return inspect($cmd) if ($firstLtr eq '/');
    }
    return $events . msg('nocmd');
}

sub updateUserTimestamp {
    my $roomst = $$cur{'roomst'};
    my $uid = $$cur{'uid'};
    if ($$cur{'ts'} - $$roomst{'u'}{$uid}[1] > $goSleepTime/2) {
        $$roomst{'u'}{$uid}[1] = $$cur{'ts'};
        roomstate($$cur{'rid'}, $roomst)
    }
}

sub you {
    my $case = $_[0] // 0;
    state @you;
    unless (@you) {
        my $youstr = msg('you');
        @you = split / /, $youstr;
        while (@you < 4) {
            push @you, $you[0];
        }
    }
    return $you[$case];
}

sub z_chgender {
    my $gen = substr $_[0], 0, 1;
    $$cur{'userd'}{'g'} = $gen;
    userdata($$cur{'uid'}, $$cur{'userd'});
    return msg("gender.$gen");
}

sub z_chname {
    my ($nom, $gen, $dat, $acc) = @_;
    if (handle($nom)) {
        return (msg('nameexists'), 1);
    }
    handle($$cur{'userd'}{'h'}, '!del');
    handle($nom, $$cur{'uid'});
    $$cur{'userd'}{'n'} = "$gen $dat $acc";
    $$cur{'userd'}{'h'} = $nom;
    userdata($$cur{'uid'}, $$cur{'userd'});
    my $userinroom = $$cur{'roomst'}{'u'}{$$cur{'uid'}};
    $$userinroom[0] = $nom;
    $$userinroom[2] = $$cur{'userd'}{'n'};
    roomstate($$cur{'rid'}, $$cur{'roomst'});
    return msg('namechanged', $nom, $gen, $dat, $acc);
}

sub z_drop {
    my ($msg, $what, $obj, $proto) = objFromUser($_[0]);
    return $msg unless defined($obj);
    user($$cur{'uid'}, $$cur{'user'});
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
    return msg('nocapacity') if @{$$cur{'user'}{'o'}} >= $maxObjInHands;
    my ($msg, $what, $obj, $proto) = objFromRoom($_[0]);
    return $msg unless defined($obj);
    roomstate($$cur{'rid'}, $$cur{'roomst'});
    push @{$$cur{'user'}{'o'}}, $obj;
    user($$cur{'uid'}, $$cur{'user'});
    return msg('get', $what);
}

sub z_give {
    my $whom = $_[1];
    my ($whomid, $nameCase) = hereUser($whom, 2);
    return msg('nouserhere', $whom) unless $whomid;
    my ($msg, $what, $obj, $proto) = objFromUser($_[0]);
    return $msg unless defined($obj);
    user($$cur{'uid'}, $$cur{'user'});
    if (exists $$proto{'f'}{'nogive'}) {
        my $room = instObj($what, $proto);
        return msg('lost', $what) . "\n" . msg($room ? 'disapp' : 'disint', $what);
    }
    my $recipient = user($whomid);
    push @{$$recipient{'o'}}, $obj;
    user($whomid, $recipient);
    my $res = msg('give', $what, $whomid, $whom);
    $res .= ' ' . msg('funny') if $$cur{'uid'} eq $whomid;
    return $res;
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
    my @objdescr = map $$_[2], @{$$roomst{'o'} || []};
    $res .= "\n" . msg('hereare', join(', ', @objdescr)) if (@objdescr);
    for my $u (keys %{$$roomst{'u'}}) {
        next if ($u == $$cur{'uid'});
        my @urec = @{$$roomst{'u'}{$u}};
        $res .= "\n" . msg(isAwake($urec[1]) ? 'hereuser' : 'heresleep', $urec[0]);
    }
    markSeen($rid);
    return $res;
}

sub z_say {
    my $phrase = $_[0];
    $phrase = trim($phrase);
    my $lastchr = substr $phrase, -1;
    my $msg = $lastchr eq '?' ? 'asked' : ($lastchr eq '!' ? 'excld' : 'said');
    $msg = msg($msg, $phrase);
    return $msg;
}

sub z_social {
    if (@_ == 1) {
        return msg('', $_[0])
    }
    my ($whom, $action) = @_;
    my $case = $_[2] // 3;
    my ($whomid, $nameCase) = hereUser($whom, $case);
    return msg('nouserhere', $whom) unless $whomid;
    return msg('social' . $case, $action, $whomid, $whom);
}

sub z_teleport {
    my $where = $_[0];
    my $newLook = z_look($where, 1);
    my $us = $$cur{'user'};
    my $h = $$cur{'userd'}{'h'};
    my $uid = $$cur{'uid'};
    $$us{'rm'} = $where;
    user($uid, $us);
    my $userinroom = $$cur{'roomst'}{'u'}{$uid};
    delete($$cur{'roomst'}{'u'}{$uid});
    roomstate($$cur{'rid'}, $$cur{'roomst'});
    my $rsnew = roomstate($where);
    $$userinroom[1] = $$cur{'ts'};
    $$rsnew{'u'}{$uid} = $userinroom;
    roomstate($where, $rsnew);
    msg('exits', $h);
    $$cur{'rid'} = $where;
    $$cur{'roomst'} = $rsnew;
    msg('enters', $h);
    return $newLook;
}

sub z_walk {
    my $dir = lc(shift @_);
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
