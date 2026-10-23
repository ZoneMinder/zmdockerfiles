#!/usr/bin/perl
# A zmNinja-style client for the event server, run inside the zoneminder container with the
# Perl modules the event server itself uses:
#
#   docker compose exec -T -e ES_USER=admin -e ES_PASS=... zoneminder \
#       perl - <monitor id> <seconds> < tests/es-client.pl
#
# Checks that a wrong password is refused, logs in, then prints one line per alarm the server
# pushes for the monitor:  start <event id> <cause>  or  end <event id> <cause>.
# Exits 0 once it has seen a start and the matching end, 1 on a timeout or any failure.
use strict;
use warnings;
use IO::Socket::SSL;
use IO::Select;
use JSON::PP;
use Protocol::WebSocket::Client;

$| = 1;
my ($monitor, $seconds) = @ARGV;
die "usage: es-client.pl <monitor id> <seconds>\n" unless $monitor && $seconds;
my ($user, $pass) = @ENV{qw(ES_USER ES_PASS)};
my $port = $ENV{ES_PORT} || 9000;
my $deadline = time + $seconds;

sub session {
    my $sock = IO::Socket::SSL->new(PeerHost => '127.0.0.1', PeerPort => $port, SSL_verify_mode => SSL_VERIFY_NONE)
        or die "connect to $port: $SSL_ERROR\n";
    my @inbox;
    my $ws = Protocol::WebSocket::Client->new(url => "wss://127.0.0.1:$port");
    $ws->on(write => sub { print {$sock} $_[1] });
    $ws->on(read => sub { push @inbox, decode_json($_[1]) });
    $ws->connect;
    my $sel = IO::Select->new($sock);
    my $recv = sub {  # next message, or undef at the deadline
        while (!@inbox) {
            my $left = $deadline - time;
            return undef if $left <= 0;
            next unless $sock->pending || $sel->can_read($left);
            my $n = sysread($sock, my $buf, 65536);
            die "event server closed the connection\n" unless $n;
            $ws->read($buf);
        }
        return shift @inbox;
    };
    my $send = sub { $ws->write(encode_json($_[0])) };
    return ($recv, $send, $sock);
}

sub auth {
    my ($recv, $send, $password) = @_;
    $send->({event => 'auth', data => {user => $user, password => $password, appversion => 'zmdockerfiles-smoke'}});
    while (my $m = $recv->()) { return $m if ($m->{event} // '') eq 'auth' }
    die "no reply to auth\n";
}

my ($recv, $send, $sock) = session();
my $r = auth($recv, $send, "$pass-wrong");
die "wrong password accepted: " . encode_json($r) . "\n" unless $r->{status} eq 'Fail';
print "wrong password refused ($r->{reason})\n";
close $sock;

($recv, $send, $sock) = session();
$r = auth($recv, $send, $pass);
die "login failed: " . encode_json($r) . "\n" unless $r->{status} eq 'Success';
print "logged in, event server $r->{version}\n";

my $started;
while (my $m = $recv->()) {
    next unless ($m->{event} // '') eq 'alarm';
    for my $a (@{$m->{events} || []}) {
        next unless $a->{MonitorId} == $monitor;
        my $end = ($a->{Cause} // '') =~ /^End:/;
        print(($end ? 'end' : 'start') . " $a->{EventId} $a->{Cause}\n");
        $started //= $a->{EventId} unless $end;
        exit 0 if $end && $started && $a->{EventId} == $started;
    }
}
print "timed out\n";
exit 1;
