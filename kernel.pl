use v5.16;
use warnings;
use File::Basename;
use lib dirname(__FILE__);
use JSON::PP;
require 'kvmem.pl';

our $autoCreateUser = 0;
our $wizPwd = 'Pl0ugh!';
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
    $$cur{'matches'} = \@m;
    return action(split(/ /, substr($act, 1))) if (substr($act, 0, 1) eq '@');
    return $act;
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
    my @descr = split /\|/, $_[0];
    $_ = trim($_) for (@descr);
    return {'d' => \@descr, 'f' => 0};
}

sub initRoom {
    return {'d' => $_[0], 'w'=> [], 'o'=> []};
}

sub initUser {
    my $uid = shift @_;
    my $user = {'rm' => 'start', 'o' => [], 'seen' => []};
    user($uid, $user);
    return $user;
}

sub inspect {
    my $get = sub { my ($elem, $subkey) = @_; ($subkey =~ m/\d+/) ? $$elem[$subkey] : $$elem{$subkey}; };
    my $cmd = $_[0];
    my $j = JSON::PP->new->allow_nonref;
    if (substr($cmd, 0, 2) eq '//') {
        $j = $j->pretty;
        $cmd = substr $cmd, 1;
    }
    my @cmd = split '=', substr $cmd, 1;
    my @path = split '/', $cmd[0];
    my $key = shift @path;
    my $obj = kvget($key);
    return "No such record in storage: $key" unless ($obj);
    my $elem = $obj;
    while (@path > 1) {
        my $subkey = shift @path;
        $elem = &$get($elem, $subkey);
        return "No subkey: $subkey" unless (defined($elem));
    }
    return $j->encode(@path ? &$get($elem, $path[0])||"no leaf for {$path[0]}": $elem) if (@cmd == 1);
    if ($cmd[1] ne '') {
        $$elem{$path[0]} = $cmd[1];
    } else {
        delete $$elem{$path[0]};
    }
    kvset($key, $obj);
    return "saved '$key':\n" . $j->new->encode($obj);
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

sub obj { return kvop('o', @_); }

sub room { return kvop('r', @_); }

sub runCmd {
    my ($uid, $cmd) = @_;
    my ($verb, $tail) = splitAndFill(' ', $cmd, 2);
    my $us = user($uid);
    return newUserComes($uid, $cmd) unless ($us);
    my $rid = $$us{'rm'};
    my $room = room($rid) || {};
    $cur = {'uid'=>$uid, 'user'=>$us, 'rid'=>$rid, 'room'=>$room};
    my %cmds = %{$$room{'c'} || {}};
    for my $pat (keys %cmds) {
        my $res = cmdMatchAndAct($pat, $cmd, $cmds{$pat});
        return $res if ($res); 
    }
    %cmds = %{meta('cmds') || {}};
    for my $pat (keys %cmds) {
        my $res = cmdMatchAndAct($pat, $cmd, $cmds{$pat});
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
        $$cmds{$pattern} = $action;
        meta('cmds', $cmds);
        return 'command added globally';
    }
    my $room = room($rid);
    return 'No such room' unless ($room);
    $$room{'c'}{$pattern} = $action;
    room($rid, $room);
    return "command added to room #$rid";
}

sub w_addobj {
    my ($oid, $descr) = splitAndFill(' ', $_[0], 2);
    obj($oid, initObj $descr);
    return "obj $oid added";
}

sub w_addmsg {
    my ($key, $phrase) = splitAndFill(' ', $_[0], 2);
    msgs($key, $phrase);
    return "message added for #$key";
}

sub w_addroom {
    my ($rid, $descr) = splitAndFill(' ', $_[0], 2);
    room($rid, initRoom($descr));
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
    push @$imports, $fname;
    meta('import', $imports);
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
    my $room = room($rid);
    return 'No such room' unless ($room);
    my $obj = obj($oid);
    return 'No such object' unless ($obj);
    push @{$$room{'o'}}, [$oid, $st];
    room ($rid, $room);
    return "obj #$oid added to room #$rid";
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
    user($$cur{'uid'}, $user);
    push @{$$cur{'room'}{'o'}}, $obj;
    room($$cur{'rid'}, $$cur{'room'});
    return msg('drop', $what);
}

sub z_get {
    my $what = $_[0];
    my $room = $$cur{'room'};
    my $idx = hasObj($room, $what);
    return msg('noobj') if ($idx < 0);
    my $obj = splice @{$$room{'o'}}, $idx, 1;
    room($$cur{'rid'}, $room);
    push @{$$cur{'user'}{'o'}}, $obj;
    user($$cur{'uid'}, $$cur{'user'});
    return msg('get', $what);
}

sub z_haveObj {
    my ($obj, $state) = split /=/, shift @_, 2;
    return msg('haveno') if (hasObj($$cur{'user'}, $obj, $state) < 0);
    return action(@_);
}

sub z_look {
    my $rid = shift @_;
    my $short = @_ ? $_[0] : 0;
    my $room;
    if (!defined($rid)) {
        $rid = $$cur{'rid'};
        $room = $$cur{'room'};
    } else {
        $room = room($rid);
    }
    my $descr = $$room{'d'} || "no room #$rid";
    my ($res, $long) = splitAndFill(qr/\|/, $descr, 2);
    $res .= "\n$long" if ($long && !($short && grep($_ eq $rid, @{$$cur{'user'}{'seen'}})));
    my @objdescr = map {
        obj($$_[0])->{'d'}[$$_[1]]
    } @{$$room{'o'} || []};
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
    $$us{'rm'} = $where;
    user($$cur{'uid'}, $us);
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
