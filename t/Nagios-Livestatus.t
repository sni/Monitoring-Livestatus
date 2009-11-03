#!/usr/bin/env perl

#########################

use Test::More tests => 1;
BEGIN { use_ok('Nagios::Livestatus') };

#########################

my $nl = Nagios::Livestatus->new({ socket => '/var/lib/nagios3/rw/livestatus.sock' });
use Data::Dumper;
print Dumper($nl->selectall_arrayref("GET hosts"));
print "-----------------------\n";
print Dumper($nl->selectall_arrayref("GET hosts", { slice => {} }));
