package Nagios::MKLivestatus::INET;

use 5.000000;
use strict;
use warnings;
use IO::Socket;
use Carp;
use base "Nagios::MKLivestatus";

=head1 NAME

Nagios::MKLivestatus::TCP - connector with tcp sockets

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus::INET->new( 'localhost:9999' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=back

=cut

sub new {
    my $class = shift;
    unshift(@_, "server") if scalar @_ == 1;
    my(%options) = @_;

    $options{'backend'} = $class;

    return Nagios::MKLivestatus->new(%options)
}


########################################
sub _send_socket {
    my $self      = shift;
    my $statement = shift;

    croak("no statement") if !defined $statement;

    if(!-S $self->{'server'}) {
        croak("failed to open socket $self->{'server'}: $!");
    }
    my $sock = IO::Socket::INET->new($self->{'server'});
    if(!defined $sock or !$sock->connected()) {
        croak("failed to connect to ($self->{'server'}): $!");
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
