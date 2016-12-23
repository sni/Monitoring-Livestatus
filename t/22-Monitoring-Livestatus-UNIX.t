#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 3;
use IO::Socket::INET;
BEGIN { use_ok('Monitoring::Livestatus::UNIX') };

#########################
# create object with single arg
my $socket = "/tmp/blah.socket";
my $ml = Monitoring::Livestatus::UNIX->new( $socket );
isa_ok($ml, 'Monitoring::Livestatus', 'Monitoring::Livestatus::UNIX->new()');

#########################
# create object with hash args
my $line_separator        = 10;
my $column_separator      = 0;
$ml = Monitoring::Livestatus::UNIX->new(
                                    verbose             => 0,
                                    socket              => $socket,
                                    line_separator      => $line_separator,
                                    column_separator    => $column_separator,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'Monitoring::Livestatus::UNIX->new(%args)');
