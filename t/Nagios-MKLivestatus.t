#!/usr/bin/env perl

#########################

use Test::More tests => 2;
BEGIN { use_ok('Nagios::MKLivestatus') };

#########################

my $nl = Nagios::MKLivestatus->new({ socket => '/var/lib/nagios3/rw/livestatus.sock' });
isa_ok($nl, 'Nagios::MKLivestatus');

use Data::Dumper;
print Dumper($nl->selectall_arrayref("GET hosts"));
print "-----------------------\n";
print Dumper($nl->selectall_arrayref("GET hosts", { slice => {} }));
