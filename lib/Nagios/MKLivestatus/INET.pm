package Nagios::MKLivestatus::INET;

use 5.000000;
use strict;
use warnings;
use IO::Socket::INET;
use Carp;
use base "Nagios::MKLivestatus";

=head1 NAME

Nagios::MKLivestatus::TCP - connector with tcp sockets

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus::INET->new( 'localhost:9999' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 CONSTRUCTOR

=over 4

=item new ( [ARGS] )

Creates an C<Nagios::MKLivestatus::INET> object. C<new> takes at least the server.
Arguments are the same as in C<Nagios::MKLivestatus>.
If the constructor is only passed a single argument, it is assumed to
be a the C<server> specification. Use either socker OR server.

=back

=cut

sub new {
    my $class = shift;
    unshift(@_, "server") if scalar @_ == 1;
    my(%options) = @_;

    $options{'backend'} = $class;
    my $self = Nagios::MKLivestatus->new(%options);
    bless $self, $class;
    return $self;
}



########################################
sub _send_socket {
    my $self      = shift;
    my $statement = shift;

    croak("no statement") if !defined $statement;

    my $sock = IO::Socket::INET->new($self->{'server'});
    if(!defined $sock or !$sock->connected()) {
        croak("failed to connect to $self->{'server'}: $!");
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
