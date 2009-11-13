package Nagios::MKLivestatus::UNIX;

use 5.000000;
use strict;
use warnings;
use IO::Socket;
use Carp;
use base "Nagios::MKLivestatus";

=head1 NAME

Nagios::MKLivestatus::UNIX - connector with unix sockets

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus::UNIX->new( '/var/lib/nagios3/rw/livestatus.sock' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=back

=cut


sub new {
    my $class = shift;
    unshift(@_, "socket") if scalar @_ == 1;
    my(%options) = @_;

    $options{'backend'} = $class;

    return Nagios::MKLivestatus->new(%options)
}

########################################
sub _send_socket {
    my $self      = shift;
    my $statement = shift;

    croak("no statement") if !defined $statement;

    if(!-S $self->{'socket'}) {
        croak("failed to open socket $self->{'socket'}: $!");
    }
    my $sock = IO::Socket::UNIX->new($self->{'socket'});
    if(!defined $sock or !$sock->connected()) {
        croak("failed to connect to ($self->{'socket'}): $!");
    }

    my $recv;
    print $sock $statement;
    $sock->shutdown(1) or croak("shutdown failed: $!");
    while(<$sock>) { $recv .= $_; }
    close($sock);

    return if !defined $recv;

    return($recv);
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
