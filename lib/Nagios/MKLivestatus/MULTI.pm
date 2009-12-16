package Nagios::MKLivestatus::MULTI;

use 5.000000;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Config;
use Time::HiRes qw( gettimeofday tv_interval );
use Nagios::MKLivestatus;
use base "Nagios::MKLivestatus";

=head1 NAME

Nagios::MKLivestatus::MULTI - connector with multiple peers

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus::MULTI->new( qw{nagioshost1:9999 nagioshost2:9999 /var/spool/nagios/live.socket} );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Nagios::MKLivestatus::MULTI> object. C<new> takes at least the server.
Arguments are the same as in C<Nagios::MKLivestatus>.

=cut

sub new {
    my $class = shift;
    unshift(@_, "peer") if scalar @_ == 1;
    my(%options) = @_;

    $options{'backend'} = $class;
    $options{'name'}    = 'multiple connector' unless defined $options{'name'};
    my $self = Nagios::MKLivestatus->new(%options);
    bless $self, $class;

    # check if we got an array of peers
    if(ref $self->{'peer'} ne 'ARRAY') {
        my $peer = $self->{'peer'};
        delete $self->{'peer'};
        @{$self->{'peer'}} = $peer;
    }

    my $peers;
    my %peer_options;
    for my $opt_key (keys %options) {
        $peer_options{$opt_key} = $options{$opt_key};
    }
    $peer_options{'errors_are_fatal'} = 0;
    for my $peer (@{$self->{'peer'}}) {
        my($remote,$type);
        if(ref $peer eq 'HASH') {
            $remote = $peer->{'peer'};
            $type   = $peer->{'type'};
        } else {
            $remote = $peer;
            $type = 'UNIX';
            if(index($peer, ':') >= 0) {
                $type = 'INET';
            }
        }
        $peer_options{'name'}   = $remote;
        $peer_options{'socket'} = $remote if $type eq 'UNIX';
        $peer_options{'server'} = $remote if $type eq 'INET';
        delete $peer_options{'peer'};

        if($type eq 'UNIX') {
            push @{$peers}, new Nagios::MKLivestatus::UNIX(%peer_options);
        }
        if($type eq 'INET') {
            push @{$peers}, new Nagios::MKLivestatus::INET(%peer_options);
        }
    }

    $self->{'peers'} = $peers;

    # dont use threads with only one peer
    if(scalar @{$peers} == 1) { $self->{'use_threads'} = 0; }

    # check for threads support
    if(!defined $self->{'use_threads'}) {
        $self->{'use_threads'} = 0;
        if($Config{useithreads}) {
            $self->{'use_threads'} = 1;
        };
    }
    if($self->{'use_threads'}) {
        require threads;
        require Thread::Queue;

        $self->_start_worker;
    }

    $self->{'logger'}->debug('initialized Nagios::MKLivestatus::MULTI '.($self->{'use_threads'} ? 'with' : 'without' ).' threads') if defined $self->{'logger'};

    return $self;
}


########################################

=head1 METHODS

=head2 do

See C<Nagios::MKLivestatus> for more information.

=cut

sub do {
    my $self  = shift;
    my $t0    = [gettimeofday];

    $self->_do_on_peers("do", @_);
    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for do('.$_[0].') in total') if defined $self->{'logger'};
    return 1;
}
########################################

=head2 selectall_arrayref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectall_arrayref {
    my $self  = shift;
    my $t0    = [gettimeofday];

    my $return  = $self->_merge_answer($self->_do_on_peers("selectall_arrayref", @_));
    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for selectall_arrayref() in total') if defined $self->{'logger'};

    return $return;
}

########################################

=head2 selectall_hashref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectall_hashref {
    my $self  = shift;
    my $t0    = [gettimeofday];

    my $return  = $self->_merge_answer($self->_do_on_peers("selectall_hashref", @_));
    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for selectall_hashref() in total') if defined $self->{'logger'};

    return $return;
}

########################################

=head2 selectcol_arrayref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectcol_arrayref {
    my $self  = shift;
    my $t0    = [gettimeofday];

    my $return  = $self->_merge_answer($self->_do_on_peers("selectcol_arrayref", @_));
    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for selectcol_arrayref() in total') if defined $self->{'logger'};

    return $return;
}

########################################

=head2 selectrow_array

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectrow_array {
    my $self      = shift;
    my $statement = $_[0];
    my $opts      = $_[1];
    my $t0        = [gettimeofday];
    my @return;

    # make opt hash keys lowercase
    %{$opts} = map { lc $_ => $opts->{$_} } keys %{$opts};

    if(defined $opts->{'sum'} or $statement =~ m/^Stats:/mx) {
        @return = @{$self->_sum_answer($self->_do_on_peers("selectrow_arrayref", @_))};
    } else {
        if($self->{'warnings'}) {
            carp("selectrow_arrayref without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("selectrow_arrayref", @_));
        @return = @{$rows->[0]} if defined $rows->[0];
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for selectrow_array() in total') if defined $self->{'logger'};

    return @return;
}

########################################

=head2 selectrow_arrayref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectrow_arrayref {
    my $self      = shift;
    my $statement = $_[0];
    my $opts      = $_[1];
    my $t0        = [gettimeofday];
    my $return;

    # make opt hash keys lowercase
    %{$opts} = map { lc $_ => $opts->{$_} } keys %{$opts};

    if(defined $opts->{'sum'} or $statement =~ m/^Stats:/mx) {
        $return = $self->_sum_answer($self->_do_on_peers("selectrow_arrayref", @_));
    } else {
        if($self->{'warnings'}) {
            carp("selectrow_arrayref without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("selectrow_arrayref", @_));
        $return = $rows->[0] if defined $rows->[0];
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for selectrow_arrayref() in total') if defined $self->{'logger'};

    return $return;
}

########################################

=head2 selectrow_hashref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectrow_hashref {
    my $self  = shift;
    my $statement = $_[0];
    my $opts      = $_[1];

    my $t0 = [gettimeofday];

    my $return;

    # make opt hash keys lowercase
    %{$opts} = map { lc $_ => $opts->{$_} } keys %{$opts};

    if(defined $opts->{'sum'} or $statement =~ m/^Stats:/mx) {
        $return = $self->_sum_answer($self->_do_on_peers("selectrow_hashref", @_));
    } else {
        if($self->{'warnings'}) {
            carp("selectrow_hashref without Stats: will not work as expected!");
        }
        $return = $self->_merge_answer($self->_do_on_peers("selectrow_hashref", @_));
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for selectrow_hashref() in total') if defined $self->{'logger'};

    return $return;
}

########################################

=head2 select_scalar_value

See C<Nagios::MKLivestatus> for more information.

=cut

sub select_scalar_value {
    my $self  = shift;
    my $statement = $_[0];
    my $opts      = $_[1];

    my $t0 = [gettimeofday];

    # make opt hash keys lowercase
    %{$opts} = map { lc $_ => $opts->{$_} } keys %{$opts};

    my $return;

    if(defined $opts->{'sum'} or $statement =~ m/^Stats:/mx) {
        return $self->_sum_answer($self->_do_on_peers("select_scalar_value", @_));
    } else {
        if($self->{'warnings'}) {
            carp("select_scalar_value without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("select_scalar_value", @_));

        $return = $rows->[0] if defined $rows->[0];
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for select_scalar_value() in total') if defined $self->{'logger'};

    return $return;
}

########################################

=head2 errors_are_fatal

See C<Nagios::MKLivestatus> for more information.

=cut

sub errors_are_fatal {
    my $self  = shift;
    my $value = shift;
    return $self->_change_setting('errors_are_fatal', $value);
}

########################################

=head2 warnings

See C<Nagios::MKLivestatus> for more information.

=cut

sub warnings {
    my $self  = shift;
    my $value = shift;
    return $self->_change_setting('warnings', $value);
}

########################################

=head2 verbose

See C<Nagios::MKLivestatus> for more information.

=cut

sub verbose {
    my $self  = shift;
    my $value = shift;
    return $self->_change_setting('verbose', $value);
}

########################################

=head2 peer_name

See C<Nagios::MKLivestatus> for more information.

=cut

sub peer_name {
    my $self  = shift;

    return wantarray ? sort keys %{$self->_do_on_peers("peer_name", @_)} : $self->{'name'};
}

########################################
# INTERNAL SUBS
########################################

sub _change_setting {
    my $self  = shift;
    my $key   = shift;
    my $value = shift;
    my $old   = $self->{$key};

    # set new value
    if(defined $value) {
        $self->{$key} = $value;
        for my $peer (@{$self->{'peers'}}) {
            $peer->{$key} = $value;
        }

        # restart workers
        if($self->{'use_threads'}) {
            _stop_worker();
            $self->_start_worker();
        }
    }

    return $old;
}

########################################
sub _start_worker {
    my $self = shift;

    # create job transports
    $self->{'WorkQueue'}   = Thread::Queue->new;
    $self->{'WorkResults'} = Thread::Queue->new;

    # set signal handler before thread is started
    # otherwise they would be killed when started
    # and stopped immediately after start
    $SIG{'USR1'} = sub { threads->exit(); };

    # start worker threads
    our %threads;
    my $threadcount = scalar @{$self->{'peers'}};
    for(my $x = 0; $x < $threadcount; $x++) {
        $self->{'threads'}->[$x] = threads->new(\&_worker_thread, $self->{'peers'}, $self->{'WorkQueue'}, $self->{'WorkResults'});
    }

    # restore sig handler as it was only for the threads
    $SIG{'USR1'} = 'DEFAULT';
    return;
}

########################################
sub _stop_worker {
    # try to kill our threads safely
    eval {
        for my $thr (threads->list()) {
            $thr->kill('USR1')->detach();
        }
    };
    return;
}

########################################
sub _worker_thread {

    my $peers       = shift;
    my $workQueue   = shift;
    my $workResults = shift;

    while (my $job = $workQueue->dequeue) {
        my $erg;
        eval {
            $erg = _do_wrapper($peers->[$job->{'peer'}], $job->{'sub'}, $job->{'logger'}, @{$job->{'opts'}});
        };
        if($@) {
            $job->{'logger'}->error("Error in Thread ".$job->{'peer'}." :".$@) if defined $job->{'logger'};
        };
        $workResults->enqueue({ peer => $job->{'peer'}, result => $erg });
    }
    return;
}

########################################
sub _do_wrapper {
    my $peer   = shift;
    my $sub    = shift;
    my $logger = shift;
    my @opts   = @_;

    my $t0 = [gettimeofday];

    my $data = $peer->$sub(@opts);

    my $elapsed = tv_interval ( $t0 );
    $logger->debug(sprintf('%.4f', $elapsed).' sec for fetching data on '.$peer->peer_name) if defined $logger;

    $Nagios::MKLivestatus::ErrorCode    = 0 unless defined $Nagios::MKLivestatus::ErrorCode;
    $Nagios::MKLivestatus::ErrorMessage = '' unless defined $Nagios::MKLivestatus::ErrorMessage;
    my $return = {
            'msg'  => $Nagios::MKLivestatus::ErrorMessage,
            'code' => $Nagios::MKLivestatus::ErrorCode,
            'data' => $data,
    };
    return $return;
}

########################################
sub _do_on_peers {
    my $self  = shift;
    my $sub   = shift;
    my @opts  = @_;
    my $statement = $opts[0];

    my $t0 = [gettimeofday];

    my $return;
    my %codes;
    my %messages;
    if($self->{'use_threads'}) {
        # create threads for all active backends
        print("using threads\n") if $self->{'verbose'};

        my $x = 0;
        for my $peer (@{$self->{'peers'}}) {
            my $job = {
                    peer   => $x,
                    sub    => $sub,
                    logger => $self->{'logger'},
                    opts   => \@opts,
            };
            $self->{'WorkQueue'}->enqueue($job);
            $x++;
        }

        for(my $x = 0; $x < scalar @{$self->{'peers'}}; $x++) {
            my $result = $self->{'WorkResults'}->dequeue;
            my $peer = $self->{'peers'}->[$result->{'peer'}];
            push @{$codes{$result->{'result'}->{'code'}}}, { 'peer' => $peer->peer_name, 'msg' => $result->{'result'}->{'msg'} };
            $return->{$peer->peer_name} = $result->{'result'}->{'data'};
        }
    } else {
        print("not using threads\n") if $self->{'verbose'};
        for my $peer (@{$self->{'peers'}}) {
            if($peer->marked_bad) {
                warn($peer->peer_name.' is marked bad') if $self->{'verbose'};
            } else {
                my $erg = _do_wrapper($peer, $sub, $self->{'logger'}, @opts);
                $return->{$peer->peer_name} = $erg->{'data'};
                push @{$codes{$erg->{'code'}}}, { 'peer' => $peer, 'msg' => $erg->{'msg'} };
            }
        }
    }


    # check if we different result stati
    undef $Nagios::MKLivestatus::ErrorMessage;
    $Nagios::MKLivestatus::ErrorCode = 0;
    my @codes = keys %codes;
    if(scalar @codes > 1) {
        # got different results for our backends
        print "got different result stati: ".Dumper(\%codes) if $self->{'verbose'};
    } else {
        # got same result codes for all backend
        my $code = $codes[0];
        if($code >= 300) {
            my $msg  = $codes{$code}->[0]->{'msg'};
            print "same: $code -> $msg\n" if $self->{'verbose'};
            $Nagios::MKLivestatus::ErrorMessage = $msg;
            $Nagios::MKLivestatus::ErrorCode    = $code;
            if($self->{'errors_are_fatal'}) {
                croak("ERROR ".$code." - ".$Nagios::MKLivestatus::ErrorMessage." in query:\n'".$statement."'\n");
            }
            return;
        }
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for fetching all data') if defined $self->{'logger'};

    return($return);
}

########################################
sub _merge_answer {
    my $self   = shift;
    my $data   = shift;
    my $return;

    my $t0 = [gettimeofday];
    for my $key (keys %{$data}) {
        $data->{$key} = [] unless defined $data->{$key};
        if(ref $data->{$key} eq 'ARRAY') {
            $return = [] unless defined $return;
            $return = [ @{$return}, @{$data->{$key}} ];
        } elsif(ref $data->{$key} eq 'HASH') {
            $return = {} unless defined $return;
            $return = { %{$return}, %{$data->{$key}} };
        } else {
            push @{$return}, $data->{$key};
        }
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for merging data') if defined $self->{'logger'};

    return($return);
}

########################################
sub _sum_answer {
    my $self   = shift;
    my $data   = shift;
    my $return;
    my $t0 = [gettimeofday];
    for my $peername (keys %{$data}) {
        if(ref $data->{$peername} eq 'HASH') {
            for my $key (keys %{$data->{$peername}}) {
                if(!defined $return->{$key}) {
                    $return->{$key} = $data->{$peername}->{$key};
                } else {
                    $return->{$key} += $data->{$peername}->{$key};
                }
            }
        }
        elsif(ref $data->{$peername} eq 'ARRAY') {
            my $x = 0;
            for my $val (@{$data->{$peername}}) {
                if(!defined $return->[$x]) {
                    $return->[$x] = $data->{$peername}->[$x];
                } else {
                    $return->[$x] += $data->{$peername}->[$x];
                }
                $x++;
            }
        }
    }

    my $elapsed = tv_interval ( $t0 );
    $self->{'logger'}->debug(sprintf('%.4f', $elapsed).' sec for summarizing data') if defined $self->{'logger'};

    return $return;
}

########################################

END {
    # try to kill our threads safely
    _stop_worker();
}

########################################

1;

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
