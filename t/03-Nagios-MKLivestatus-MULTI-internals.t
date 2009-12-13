#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 4;
use Data::Dumper;
use_ok('Nagios::MKLivestatus::MULTI');

#########################
# test the _merge_answer
my $mergetests = [
    {   # simple test for sliced selectall_arrayref
        in  => { '192.168.123.2:9996' => [ { 'description' => 'test_flap_07',     'host_name' => 'test_host_000', 'state' => '0' }, { 'description' => 'test_flap_11',     'host_name' => 'test_host_000', 'state' => '0' } ],
                 '192.168.123.2:9997' => [ { 'description' => 'test_ok_00',       'host_name' => 'test_host_000', 'state' => '0' }, { 'description' => 'test_ok_01',       'host_name' => 'test_host_000', 'state' => '0' } ],
                 '192.168.123.2:9998' => [ { 'description' => 'test_critical_00', 'host_name' => 'test_host_000', 'state' => '2' }, { 'description' => 'test_critical_19', 'host_name' => 'test_host_000', 'state' => '2' } ]
        },
        exp => [ { 'description' => 'test_critical_00', 'host_name' => 'test_host_000', 'state' => '2' },
                 { 'description' => 'test_critical_19', 'host_name' => 'test_host_000', 'state' => '2' },
                 { 'description' => 'test_flap_07',     'host_name' => 'test_host_000', 'state' => '0' },
                 { 'description' => 'test_flap_11',     'host_name' => 'test_host_000', 'state' => '0' },
                 { 'description' => 'test_ok_00',       'host_name' => 'test_host_000', 'state' => '0' },
                 { 'description' => 'test_ok_01',       'host_name' => 'test_host_000', 'state' => '0' }
               ]
    },
];

my $x = 0;
for my $test (@{$mergetests}) {
    my $got = Nagios::MKLivestatus::MULTI->_merge_answer($test->{'in'});
    is_deeply($got, $test->{'exp'}, '_merge_answer test '.$x)
        or diag("got: ".Dumper($got)."\nbut expected ".Dumper($test->{'exp'}));
    $x++;
}

#########################
# test the _sum_answer
my $sumtests = [
    { # hashes
        in  => { '192.168.123.2:9996' => { 'ok' => '12', 'warning' => '8' },
                 '192.168.123.2:9997' => { 'ok' => '17', 'warning' => '7' },
                 '192.168.123.2:9998' => { 'ok' => '13', 'warning' => '2' }
        },
        exp => { 'ok' => '42', 'warning' => '17' }
    },
    { # arrays
        in  => { '192.168.123.2:9996' => [ '3302', '235' ],
                 '192.168.123.2:9997' => [ '3324', '236' ],
                 '192.168.123.2:9998' => [ '3274', '236' ]
        },
        exp => [ 9900, 707 ]
    },
];

$x = 0;
for my $test (@{$sumtests}) {
    my $got = Nagios::MKLivestatus::MULTI->_sum_answer($test->{'in'});
    is_deeply($got, $test->{'exp'}, '_sum_answer test '.$x)
        or diag("got: ".Dumper($got)."\nbut expected ".Dumper($test->{'exp'}));
    $x++;
}
