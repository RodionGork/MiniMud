use v5.16;
use warnings;

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
    my ($tag, $descr) = splitAndFill(' ', $_[0], 2);
    my ($oid, $synonyms) = splitAndFill(':', $tag, 2);
    my $proto = initObj $descr, $synonyms;
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

1;
