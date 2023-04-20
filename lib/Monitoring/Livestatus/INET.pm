package Monitoring::Livestatus::INET;
use warnings;
use strict;
use Carp qw/confess/;
use IO::Socket::IP ();
use Socket qw(IPPROTO_TCP TCP_NODELAY);

use parent 'Monitoring::Livestatus';

=head1 NAME

Monitoring::Livestatus::INET - connector with tcp sockets

=head1 SYNOPSIS

    use Monitoring::Livestatus;
    my $nl = Monitoring::Livestatus::INET->new( 'localhost:9999' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Monitoring::Livestatus::INET> object. C<new> takes at least the server.
Arguments are the same as in C<Monitoring::Livestatus>.
If the constructor is only passed a single argument, it is assumed to
be a the C<server> specification. Use either socker OR server.

=cut

sub new {
    my($class, @args) = @_;
    unshift(@args, "peer") if scalar @args == 1;
    my(%options) = @args;
    $options{'name'} = $options{'peer'} unless defined $options{'name'};

    $options{'backend'} = $class;
    my $self = Monitoring::Livestatus->new(%options);
    bless $self, $class;
    confess('not a scalar') if ref $self->{'peer'} ne '';

    if(($self->{'peer'}//$self->{'server'}) =~ m|^tls://|mx) {
        require IO::Socket::SSL;
    }

    return $self;
}


########################################

=head1 METHODS

=cut

sub _open {
    my $self = shift;
    my $sock;

    my $options = {
        PeerAddr => $self->{'peer'},
        Type     => IO::Socket::IP::SOCK_STREAM,
        Timeout  => $self->{'connect_timeout'},
    };

    my $tls = 0;
    my $peer_addr = $self->{'peer'};
    if($peer_addr =~ s|tls://||mx) {
        #$IO::Socket::SSL::DEBUG = 2 if $ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 2;
        #$IO::Socket::SSL::DEBUG = 3 if $ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 3;
        $options->{'PeerAddr'} = $peer_addr;
        $options->{'SSL_cert_file'}   = $self->{'cert'};
        $options->{'SSL_key_file'}    = $self->{'key'};
        $options->{'SSL_ca_file'}     = $self->{'ca_file'};
        $options->{'SSL_verify_mode'} = 0 if(defined $self->{'verify'} && $self->{'verify'} == 0);
        $options->{'SSL_verifycn_name'} = $self->{'verifycn_name'};
        $tls = 1;
    }

    eval {
        if($tls) {
            $sock = IO::Socket::SSL->new(%{$options});
        } else {
            $sock = IO::Socket::IP->new(%{$options});
        }
        if(!defined $sock || !$sock->connected()) {
            my $msg = "failed to connect to $peer_addr: ".($tls ? IO::Socket::SSL::errstr() : $!);
            if($self->{'errors_are_fatal'}) {
                confess($msg);
            }
            $Monitoring::Livestatus::ErrorCode    = 500;
            $Monitoring::Livestatus::ErrorMessage = $msg;
            return;
        }

        setsockopt($sock, IPPROTO_TCP, TCP_NODELAY, 1);

    };
    my $err = $@;

    if($err) {
        $Monitoring::Livestatus::ErrorCode    = 500;
        $Monitoring::Livestatus::ErrorMessage = $err;
        return;
    }

    if(defined $self->{'query_timeout'}) {
        # set timeout
        $sock->timeout($self->{'query_timeout'});
    }

    return($sock);
}


########################################

sub _close {
    my $self = shift;
    my $sock = shift;
    return unless defined $sock;
    return close($sock);
}


1;

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
