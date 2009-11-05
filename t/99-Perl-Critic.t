#!/usr/bin/env perl
#
# $Id$
#
use Test::More;

BEGIN {
  eval {require Test::Perl::Critic;};

  if ( $@ ) {
    plan skip_all => 'Test::Perl::Critic not installed'
  }else{
    plan tests => 2
  }
}

use Test::Perl::Critic;
use_ok("Nagios::MKLivestatus");
critic_ok($INC{'Nagios/MKLivestatus.pm'});