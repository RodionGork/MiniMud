use v5.16;
use warnings;
use Digest::SHA;
use Digest::MD5;
use MIME::Base64;

die 'need pwd as firs cmd line argument' unless @ARGV > 0;

my $pwd = $ARGV[0];
my $decode = -1;

while (my $line = <STDIN>) {
    chomp $line;
    if ($decode < 0) {
        if ($line eq '!encrypted') {
            $decode = 1;
            next;
        } else {
            say '!encrypted';
            $decode = 0;
        }
    }
    if ($line eq '') {
        say '';
    } elsif (!$decode) {
        my @bytes = split //, $line;
        my $salt = substr Digest::MD5::md5_base64($line), -4;
        my @key = split //, Digest::SHA::sha512($salt . $pwd);
        for (my $i = 0; $i < @bytes; $i++) {
            $bytes[$i] ^= $key[$i%@key];
        }
        say $salt . MIME::Base64::encode_base64(join('', @bytes), '');
    } else {
        my $salt = substr $line, 0, 4;
        my @bytes = split //, MIME::Base64::decode_base64(substr $line, 4);
        my @key = split //, Digest::SHA::sha512($salt . $pwd);
        for (my $i = 0; $i < @bytes; $i++) {
            $bytes[$i] ^= $key[$i%@key];
        }
        say join '', @bytes;
    }
}
