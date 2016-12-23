#!/usr/bin/env perl

#########################

use strict;
use Test::More;
use File::Temp;
use Data::Dumper;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use_ok('Monitoring::Livestatus');

BEGIN {
    if( $^O eq 'MSWin32' ) {
        plan skip_all => 'no sockets on windows';
    }
    else {
        plan tests => 29;
    }
}

#########################
# get a temp file from File::Temp and replace it with our socket
my $fh = File::Temp->new(UNLINK => 0);
my $socket_path = $fh->filename;
unlink($socket_path);
my $listener = IO::Socket::UNIX->new(
                                    Type    => SOCK_STREAM,
                                    Listen  => SOMAXCONN,
                                    Local   => $socket_path,
                                  ) or die("failed to open $socket_path as test socket: $!");
#########################
# create object with single arg
my $ml = Monitoring::Livestatus->new( $socket_path );
isa_ok($ml, 'Monitoring::Livestatus', 'single args');
is($ml->peer_name(), $socket_path, 'get peer_name()');
is($ml->peer_addr(), $socket_path, 'get peer_addr()');

#########################
# create object with hash args
my $line_separator        = 10;
my $column_separator      = 0;
$ml = Monitoring::Livestatus->new(
                                    verbose             => 0,
                                    socket              => $socket_path,
                                    line_separator      => $line_separator,
                                    column_separator    => $column_separator,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'new hash args');
is($ml->peer_name(), $socket_path, 'get peer_name()');
is($ml->peer_addr(), $socket_path, 'get peer_addr()');

#########################
# create object with peer arg
$ml = Monitoring::Livestatus->new(
                                    peer              => $socket_path,
                               );
isa_ok($ml, 'Monitoring::Livestatus', 'peer hash arg socket');
is($ml->peer_name(), $socket_path, 'get peer_name()');
is($ml->peer_addr(), $socket_path, 'get peer_addr()');
isa_ok($ml->{'CONNECTOR'}, 'Monitoring::Livestatus::UNIX', 'peer backend UNIX');

#########################
# create object with peer arg
my $server = 'localhost:12345';
$ml = Monitoring::Livestatus->new(
                                    peer              => $server,
                               );
isa_ok($ml, 'Monitoring::Livestatus', 'peer hash arg server');
is($ml->peer_name(), $server, 'get peer_name()');
is($ml->peer_addr(), $server, 'get peer_addr()');
isa_ok($ml->{'CONNECTOR'}, 'Monitoring::Livestatus::INET', 'peer backend INET');

#########################
$ml = Monitoring::Livestatus->new(
                                     peer        => [ $socket_path ],
                                     verbose     => 0,
                                     keepalive   => 1,
                                     logger      => undef,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'peer hash arg multi with keepalive');
is($ml->peer_name(), $socket_path, 'get peer_name()');
is($ml->peer_addr(), $socket_path, 'get peer_addr()');

#########################
# timeout checks
$ml = Monitoring::Livestatus->new(
                                     peer        => [ $socket_path ],
                                     verbose     => 0,
                                     timeout     => 13,
                                     logger      => undef,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'peer hash arg multi with general timeout');
is($ml->peer_name(), $socket_path, 'get peer_name()');
is($ml->peer_addr(), $socket_path, 'get peer_addr()');
is($ml->{'connect_timeout'}, 13,   'connect_timeout');
is($ml->{'query_timeout'}, 13,     'query_timeout');

$ml = Monitoring::Livestatus->new(
                                     peer            => [ $socket_path ],
                                     verbose         => 0,
                                     query_timeout   => 14,
                                     connect_timeout => 17,
                                     logger          => undef,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'peer hash arg multi with general timeout');
is($ml->peer_name(), $socket_path, 'get peer_name()');
is($ml->peer_addr(), $socket_path, 'get peer_addr()');
is($ml->{'connect_timeout'}, 17,   'connect_timeout');
is($ml->{'query_timeout'}, 14,     'query_timeout');


#########################
# error retry
$ml = Monitoring::Livestatus->new(
                                     peer                        => [ $socket_path ],
                                     verbose                     => 0,
                                     retries_on_connection_error => 3,
                                     retry_interval              => 1,
                                     logger                      => undef,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'peer hash arg multi with error retry');

#########################
# cleanup
unlink($socket_path);
