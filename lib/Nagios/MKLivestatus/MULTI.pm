package Nagios::MKLivestatus::MULTI;

use 5.000000;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Config;
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
    my $self = \%options;
    bless $self, $class;

    my $peers;
    my %peer_options;
    for my $opt_key (keys %options) {
        $peer_options{$opt_key} = $options{$opt_key};
    }
    $peer_options{'errors_are_fatal'} = 0;
    for my $peer (@{$self->{'peer'}}) {
        my $remote = $peer->{'peer'};
        my $type   = $peer->{'type'};
        $peer_options{'name'}   = $remote;
        $peer_options{'socket'} = $remote if $type eq 'UNIX';
        $peer_options{'server'} = $remote if $type eq 'INET';

        if($type eq 'UNIX') {
            push @{$peers}, new Nagios::MKLivestatus::UNIX(%peer_options);
        }
        if($type eq 'INET') {
            push @{$peers}, new Nagios::MKLivestatus::INET(%peer_options);
        }
    }

    $self->{'peers'} = $peers;

    # check for threads support
    if(!defined $self->{'use_threads'}) {
        $self->{'use_threads'} = 0;
        if($Config{useithreads}) {
            $self->{'use_threads'} = 1;
        };
    }
    if($self->{'use_threads'}) {
        eval {
            require threads;
        };
    }

    return $self;
}


########################################

=head1 METHODS

=head2 do

See C<Nagios::MKLivestatus> for more information.

=cut

sub do {
    my $self  = shift;
    $self->_do_on_peers("do", @_);
    return 1;
}
########################################

=head2 selectall_arrayref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectall_arrayref {
    my $self  = shift;
    return $self->_merge_answer($self->_do_on_peers("selectall_arrayref", @_));
}

########################################

=head2 selectall_hashref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectall_hashref {
    my $self  = shift;
    return $self->_merge_answer($self->_do_on_peers("selectall_hashref", @_));
}

########################################

=head2 selectcol_arrayref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectcol_arrayref {
    my $self  = shift;
    return $self->_merge_answer($self->_do_on_peers("selectcol_arrayref", @_));
}

########################################

=head2 selectrow_array

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectrow_array {
    my $self  = shift;
    my $statement = $_[0];
    if($statement =~ m/^Stats:/mx) {
        return @{$self->_sum_answer($self->_do_on_peers("selectrow_arrayref", @_))};
    } else {
        if($self->{'warnings'}) {
            carp("selectrow_arrayref without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("selectrow_arrayref", @_));
        return @{$rows->[0]} if defined $rows->[0];
    }
    return;
}

########################################

=head2 selectrow_arrayref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectrow_arrayref {
    my $self  = shift;
    my $statement = $_[0];
    if($statement =~ m/^Stats:/mx) {
        return $self->_sum_answer($self->_do_on_peers("selectrow_arrayref", @_));
    } else {
        if($self->{'warnings'}) {
            carp("selectrow_arrayref without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("selectrow_arrayref", @_));
        return $rows->[0] if defined $rows->[0];
    }
    return;
}

########################################

=head2 selectrow_hashref

See C<Nagios::MKLivestatus> for more information.

=cut

sub selectrow_hashref {
    my $self  = shift;
    my $statement = $_[0];
    if($statement =~ m/^Stats:/mx) {
        return $self->_sum_answer($self->_do_on_peers("selectrow_hashref", @_));
    } else {
        if($self->{'warnings'}) {
            carp("selectrow_hashref without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("selectrow_hashref", @_));
        return $rows->[0] if defined $rows->[0];
    }
    return;
}

########################################

=head2 select_scalar_value

See C<Nagios::MKLivestatus> for more information.

=cut

sub select_scalar_value {
    my $self  = shift;
    my $statement = $_[0];
    if($statement =~ m/^Stats:/mx) {
        return $self->_sum_answer($self->_do_on_peers("select_scalar_value", @_));
    } else {
        if($self->{'warnings'}) {
            carp("select_scalar_value without Stats: will not work as expected!");
        }
        my $rows = $self->_merge_answer($self->_do_on_peers("select_scalar_value", @_));
        return $rows->[0] if defined $rows->[0];
    }
    return;
}

########################################

=head2 errors_are_fatal

See C<Nagios::MKLivestatus> for more information.

=cut

sub errors_are_fatal {
    my $self  = shift;
    $self->{'errors_are_fatal'} = $_[0] if defined $_[0];
    for my $peer (@{$self->{'peers'}}) {
        $peer->{'errors_are_fatal'} = $_[0];
    }
    return 1;
}

########################################

=head2 warnings

See C<Nagios::MKLivestatus> for more information.

=cut

sub warnings {
    my $self  = shift;
    $self->{'warnings'} = $_[0] if defined $_[0];
    for my $peer (@{$self->{'peers'}}) {
        $peer->{'warnings'} = $_[0];
    }
    return 1;
}

########################################

=head2 verbose

See C<Nagios::MKLivestatus> for more information.

=cut

sub verbose {
    my $self  = shift;
    $self->{'verbose'} = $_[0] if defined $_[0];
    return $self->_do_on_peers("verbose", @_);
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
sub _do_wrapper {
    my $peer = shift;
    my $sub  = shift;
    my @opts = @_;
    my $data = $peer->$sub(@opts);

    #if($Nagios::MKLivestatus::ErrorCode) {
    #    croak($Nagios::MKLivestatus::ErrorMessage);
    #}

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

    my $return;
    my %codes;
    my %messages;
    if($self->{'use_threads'}) {
        # create threads for all active backends
        print("using threads\n") if $self->{'verbose'};
        my %threads;
        for my $peer (@{$self->{'peers'}}) {
            if($peer->marked_bad) {
                warn($peer->peer_name.' is marked bad') if $self->{'verbose'};
            } else {
                $threads{$peer->peer_name} = threads->new(\&_do_wrapper, $peer, $sub, @opts);
            }
        }
        for my $peer_name (keys %threads) {
            my $erg = $threads{$peer_name}->join();
            $return->{$peer_name} = $erg->{'data'};
            push @{$codes{$erg->{'code'}}}, { 'peer' => $peer_name, 'msg' => $erg->{'msg'} };
        }
    } else {
        print("not using threads\n") if $self->{'verbose'};
        for my $peer (@{$self->{'peers'}}) {
            if($peer->marked_bad) {
                warn($peer->peer_name.' is marked bad') if $self->{'verbose'};
            } else {
                my $erg = _do_wrapper($peer, $sub, @opts);
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

    return($return);
}

########################################
sub _merge_answer {
    my $self   = shift;
    my $data   = shift;
    my $return = [];
    for my $key (keys %{$data}) {
        $data->{$key} = [] unless defined $data->{$key};
        if(ref $data->{$key} eq 'ARRAY') {
            $return = [ @{$return}, @{$data->{$key}} ];
        } else {
            push @{$return}, $data->{$key};
        }
    }
    return($return);
}

########################################
sub _sum_answer {
    my $self   = shift;
    my $data   = shift;
    my $return;
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

    return $return;
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
