#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 6;
use threads;
use File::Temp;
BEGIN { use_ok('Nagios::MKLivestatus') };

#########################
my $line_seperator        = 10;
my $column_seperator      = 0;
my $test_host_result      = [ ["a","b","c"], ["d","e","f"], ["g","h","i"] ];
my $test_host_result_arr  = [ ["d","e","f"], ["g","h","i"] ];
my $test_host_result_hash = [ { 'c' => 'f', 'a' => 'd', 'b' => 'e' }, { 'c' => 'i', 'a' => 'g', 'b' => 'h' } ];

#########################
# get a temp file from File::Temp and replace it with our socket
my $fh = File::Temp->new();
my $socket_path = $fh->filename;
unlink($socket_path);
my $thr = threads->create('create_socket');
sleep(1);

#########################
# create object with single arg
my $nl = Nagios::MKLivestatus->new( $socket_path );
isa_ok($nl, 'Nagios::MKLivestatus', 'single args');

#########################
# create object with hash args
$nl = Nagios::MKLivestatus->new(
                                    verbose             => 0,
                                    socket              => $socket_path,
                                    line_seperator      => $line_seperator,
                                    column_seperator    => $column_seperator,
                                );
isa_ok($nl, 'Nagios::MKLivestatus', 'new hash args');

#########################
# do some sample querys
my $hosts1 = $nl->selectall_arrayref("GET hosts");
is_deeply($hosts1, $test_host_result_arr, 'selectall_arrayref GET hosts');
my $hosts2 = $nl->selectall_arrayref("GET hosts", { slice => {} });
is_deeply($hosts2, $test_host_result_hash, 'selectall_arrayref GET hosts sliced');


#########################
# exit tests
my $exited_ok = $nl->do("exit");
is($exited_ok, 1, 'exiting test socket');
exit;


#########################
# SUBS
#########################
# test socket server
sub create_socket {
    use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
    my $listener = IO::Socket::UNIX->new(
                                        Type    => SOCK_STREAM,
                                        Listen  => SOMAXCONN,
                                        Local   => $socket_path,
                                      ) or die("failed to open $socket_path as test socket: $!");
    while( my $socket = $listener->accept() or die('cannot accept: $!') ) {
        my $recv = "";
        while(<$socket>) { $recv .= $_; }
        return if $recv =~ '^exit';
        if($recv =~ '^GET hosts') {
            print $socket join( chr($line_seperator), map( join( chr($column_seperator), @{$_}), @{$test_host_result} ) )."\n";
        }
    }
    unlink($socket_path);
}