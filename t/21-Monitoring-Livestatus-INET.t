#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 3;
use IO::Socket::INET;
BEGIN { use_ok('Monitoring::Livestatus::INET') };

#########################
# create a tmp listener
my $server = 'localhost:9999';
my $listener = IO::Socket::INET->new(
                                  ) or die("failed to open port as test listener: $!");
#########################
# create object with single arg
my $ml = Monitoring::Livestatus::INET->new( $server );
isa_ok($ml, 'Monitoring::Livestatus', 'Monitoring::Livestatus::INET->new()');

#########################
# create object with hash args
my $line_separator        = 10;
my $column_separator      = 0;
$ml = Monitoring::Livestatus::INET->new(
                                    verbose             => 0,
                                    server              => $server,
                                    line_separator      => $line_separator,
                                    column_separator    => $column_separator,
                                );
isa_ok($ml, 'Monitoring::Livestatus', 'Monitoring::Livestatus::INET->new(%args)');
