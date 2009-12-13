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

=cut

sub do {
    my $self  = shift;
    return $self->_do_on_peers("do", @_);
}

########################################
sub _do_wrapper {
    my $peer = shift;
    my $sub  = shift;
    my @opts = @_;
    return $peer->$sub(@opts);
}
########################################

sub _do_on_peers {
    my $self  = shift;
    my $sub   = shift;
    my @opts  = @_;

    my $return;
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
            $return->{$peer_name} = $threads{$peer_name}->join();
        }
    } else {
        print("not using threads\n") if $self->{'verbose'};
        for my $peer (@{$self->{'peers'}}) {
            if($peer->marked_bad) {
                warn($peer->peer_name.' is marked bad') if $self->{'verbose'};
            } else {
                $return->{$peer->peer_name} = $peer->$sub(@opts);
            }
        }
    }
    return($return);
}

########################################
sub selectall_arrayref {
    my $self  = shift;
    return $self->_merge_answer($self->_do_on_peers("selectall_arrayref", @_));
}

########################################
sub selectall_hashref {
    my $self  = shift;
    return $self->_merge_answer($self->_do_on_peers("selectall_hashref", @_));
}

########################################
sub selectcol_arrayref {
    my $self  = shift;
    return $self->_merge_answer($self->_do_on_peers("selectcol_arrayref", @_));
}

########################################
sub selectrow_array {
    my $self  = shift;
    return @{$self->_sum_answer($self->_do_on_peers("selectrow_arrayref", @_))};
}

########################################
sub selectrow_arrayref {
    my $self  = shift;
    return $self->_sum_answer($self->_do_on_peers("selectrow_arrayref", @_));
}

########################################
sub selectrow_hashref {
    my $self  = shift;
    return $self->_sum_answer($self->_do_on_peers("selectrow_hashref", @_));
}

########################################
sub select_scalar_value {
    my $self  = shift;
    return $self->_do_on_peers("select_scalar_value", @_);
}

########################################
sub errors_are_fatal {
    my $self  = shift;
    return $self->_do_on_peers("errors_are_fatal", @_);
}

########################################
sub verbose {
    my $self  = shift;
    return $self->_do_on_peers("verbose", @_);
}

########################################
sub peer_name {
    my $self  = shift;

    return wantarray ? @{$self->_do_on_peers("peer_name", @_)} : $self->{'name'};
}

########################################
sub _merge_answer {
    my $self   = shift;
    my $data   = shift;
#    print Dumper($data);
    my $return = [];
    for my $key (keys %{$data}) {
        $return = [ @{$return}, @{$data->{$key}} ];
    }
#    print Dumper($return);
    return($return);
}

########################################
sub _sum_answer {
    my $self   = shift;
    my $data   = shift;
    print "#############################################################\n";
    print Dumper($data);
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
    print Dumper($return);
    print "#############################################################\n";
    #return($return);

    return $return;
}

1;

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
