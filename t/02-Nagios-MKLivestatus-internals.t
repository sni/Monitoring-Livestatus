#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 5;
use File::Temp;
use Data::Dumper;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use_ok('Nagios::MKLivestatus');

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
my $nl = Nagios::MKLivestatus->new( $socket_path );
isa_ok($nl, 'Nagios::MKLivestatus', 'single args');

my $header = "404          43\n";
my($error,$error_msg) = $nl->_parse_header($header);
is($error, '404', 'error code 404');
isnt($error_msg, undef, 'error code 404 message');

#########################
my $stats_query1 = "GET services
Stats: state = 0
Stats: state = 1
Stats: state = 2
Stats: state = 3
Stats: state = 4
Stats: host_state != 0
Stats: state = 1
StatsAnd: 2
Stats: host_state != 0
Stats: state = 2
StatsAnd: 2
Stats: host_state != 0
Stats: state = 3
StatsAnd: 2
Stats: host_state != 0
Stats: state = 3
Stats: active_checks = 1
StatsAnd: 3
Stats: state = 3
Stats: active_checks = 1
StatsOr: 2";
my @expected_keys = (
            'state = 0',
            'state = 1',
            'state = 2',
            'state = 3',
            'state = 4',
            'host_state != 0 && state = 1',
            'host_state != 0 && state = 2',
            'host_state != 0 && state = 3',
            'host_state != 0 && state = 3 && active_checks = 1',
            'state = 3 || active_checks = 1',
        );
my @got_keys = @{$nl->_extract_keys_from_stats_statement($stats_query1)};
is_deeply(\@got_keys, \@expected_keys, 'statsAnd, statsOr query keys')
    or ( diag('got keys: '.Dumper(\@got_keys)) );


#########################
unlink($socket_path);
