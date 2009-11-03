package Nagios::MKLivestatus;

use 5.008008;
use strict;
use warnings;
use IO::Socket;
use Data::Dumper;
use Carp;

our $VERSION = '0.10';

########################################
sub new {
    my $class   = shift;
    my $options = shift;
    my $self = {
                    "verbose"                   => 0,
                    "socket"                    => undef,
                    "line_seperator"            => 10,   # defaults to newline
                    "column_seperator"          => 0,    # defaults to null byte
                    "list_seperator"            => 44,   # defaults to comma
                    "host_service_seperator"    => 124,  # defaults to pipe
               };
    bless $self, $class;

    for my $opt_key (keys %{$options}) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options->{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    if(!defined $self->{'socket'}) {
        croak('no socket given');
    }

    return $self;
}

sub _send {
    my $self      = shift;
    my $statement = shift;
    if(!-S $self->{'socket'}) {
        croak("failed to open socket $self->{'socket'}: $!");
    }
    my $sock = IO::Socket::UNIX->new($self->{'socket'});
    if(!defined $sock or !$sock->connected()) {
        croak("failed to connect: $!");
        return(undef);
    }
    my ($recv, @result);
    $sock->send("$statement\nSeparators: $self->{'line_seperator'} $self->{'column_seperator'} $self->{'list_seperator'} $self->{'host_service_seperator'}");
    $sock->shutdown(1);
    while($sock->recv(my $data, 1024)) { $recv .= $data; }

    my $line_seperator = chr($self->{'line_seperator'});
    my $col_seperator  = chr($self->{'column_seperator'});

    for my $line (split/$line_seperator/, $recv) {
        push @result, [ split/$col_seperator/, $line ];
    }

    my $keys = shift @result;
    return({ keys => $keys, result => \@result});
}

sub selectall_arrayref {
    my $self      = shift;
    my $statement = shift;
    my $slice     = shift;

    my $result = $self->_send($statement);

    if(defined $slice and ref $slice eq 'HASH') {
        # make an array of hashes
        my @hash_refs;
        for my $res (@{$result->{'result'}}) {
            my $hash_ref;
            for(my $x=0;$x<scalar @{$res};$x++) {
                $hash_ref->{$result->{'keys'}->[$x]} = $res->[$x];
            }
            push @hash_refs, $hash_ref;
        }
        return(\@hash_refs);
    }

    return($result->{'result'});
}

#selectall_hashref($statement, $key_field);
#selectcol_arrayref($statement);
#selectcol_arrayref($statement, \%attr);
#selectrow_array($statement);
#selectrow_arrayref($statement);
#selectrow_hashref($statement);


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Nagios::MKLivestatus - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Nagios::MKLivestatus;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Nagios::MKLivestatus, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

root, E<lt>root@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by root

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
