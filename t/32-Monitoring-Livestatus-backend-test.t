#!/usr/bin/env perl

#########################

use strict;
use Test::More;
use Data::Dumper;

if ( ! defined $ENV{TEST_SOCKET} or !defined $ENV{TEST_SERVER} or !defined $ENV{TEST_BACKEND} ) {
    my $msg = 'Author test.  Set $ENV{TEST_SOCKET} and $ENV{TEST_SERVER} and $ENV{TEST_BACKEND} to run';
    plan( skip_all => $msg );
} else {
# we dont know yet how many tests we got
#    plan( tests => 2131 );
}

# set an alarm
$SIG{ALRM} = sub {
    my @caller = caller;
    die "timeout reached:".Dumper(\@caller)."\n" 
};
alarm(120);

use_ok('Monitoring::Livestatus');

#########################
my $objects_to_test = {
  # UNIX
  '01 unix_single_arg' => Monitoring::Livestatus::UNIX->new( $ENV{TEST_SOCKET} ),

  # TCP
  '02 inet_single_arg' => Monitoring::Livestatus::INET->new( $ENV{TEST_SERVER} ),

  # MULTI
  '03 multi_keepalive' => Monitoring::Livestatus->new( [ $ENV{TEST_SERVER}, $ENV{TEST_SOCKET} ] ),
};

for my $key (sort keys %{$objects_to_test}) {
    my $ml = $objects_to_test->{$key};
    isa_ok($ml, 'Monitoring::Livestatus') or BAIL_OUT("no need to continue without a proper Monitoring::Livestatus object: ".$key);

    # dont die on errors
    $ml->errors_are_fatal(0);
    $ml->warnings(0);

    #########################
    # get tables
    my $data            = $ml->selectall_hashref("GET columns\nColumns: table", 'table');
    my @tables          = sort keys %{$data};

    #########################
    # check keys
    for my $type (@tables) {
        my $filter = "";
        $filter  = "Filter: time > ".(time() - 600)."\n" if $type eq 'log';
        $filter .= "Filter: time < ".(time())."\n"       if $type eq 'log';
        my $statement = "GET $type\n".$filter."Limit: 1";
        my $keys  = $ml->selectrow_hashref($statement );
        is(ref $keys, 'HASH', $type.' keys are a hash');# or BAIL_OUT('keys are not in hash format, got '.Dumper($keys));

        # status has no filter implemented
        next if $type eq 'status';

        for my $key (keys %{$keys}) {
            my $value = $keys->{$key};
            if(index($value, ',') > 0) { my @vals = split /,/, $value; $value = $vals[0];  }
            my $typefilter = "Filter: $key >= $value\n";
            if($value eq '') {
                $typefilter = "Filter: $key =\n";
            }
            my $statement  = "GET $type\n".$filter.$typefilter."Limit: 1";
            my $hash_ref   = $ml->selectrow_hashref($statement );
            is($Monitoring::Livestatus::ErrorCode, 0, "GET ".$type." Filter: ".$key." >= ".$value) or BAIL_OUT("query failed: ".$statement);
            #isnt($hash_ref, undef, "GET ".$type." Filter: ".$key." >= ".$value);# or BAIL_OUT("got undef for ".$statement);

            # wait till backend is started up again
            if(!defined $hash_ref and $Monitoring::Livestatus::ErrorCode > 200) { 
                sleep(2);
            }
        }
    }
}

done_testing();
