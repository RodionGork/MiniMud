use v5.16;
use warnings;
use MIME::Base64;
use Digest::SHA;

sub tokenSecret {
    my $res = $ENV{'TOKEN_SECRET'} // '';
    return $res;
}

sub makeToken {
    my ($uid, $srv) = @_;
    my $ts = time();
    my $tkn = "$uid $srv $ts";
    my $sha = Digest::SHA::sha1_base64(tokenSecret() . $tkn);
    my $tkn64 = encode_base64($tkn, '');
    $tkn64 =~ s/=//g;
    my $res = $sha . $tkn64;
    $res =~ tr/+\//-_/;
    return $res;
}

sub parseToken {
    my $tkn = $_[0];
    $tkn =~ tr/-_/+\//;
    return '', '', '' if length($tkn) < 64;
    my $sha = substr $tkn, 0, 27;
    $tkn = decode_base64(substr $tkn, 27);
    my $sha2 = Digest::SHA::sha1_base64(tokenSecret() . $tkn);
    return '', '', '' unless $sha2 eq $sha;
    return split / /, $tkn;
}

if (@ARGV > 0) {
    if (length($ARGV[0]) < 64) {
        print makeToken($ARGV[0], 'http://localhost:8001/cgi-bin/run-cmd.sh') . "\n";
    } else {
        my ($uid, $srv, $ts) = parseToken $ARGV[0];
        print "$uid, $ts, $srv\n";
    }
} else {
    1;
}
