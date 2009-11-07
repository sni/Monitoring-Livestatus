package Nagios::MKLivestatus;

use 5.008000;
use strict;
use warnings;
use IO::Socket;
use Data::Dumper;
use Carp;

our $VERSION = '0.15';


=head1 NAME

Nagios::MKLivestatus - access nagios runtime data from check_mk livestatus Nagios addon

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus->new( socket => '/var/lib/nagios3/rw/livestatus.sock' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 DESCRIPTION

This module connects via socket to the check_mk livestatus nagios addon. You first have
to install and activate the livestatus addon in your nagios installation.


=head1 CONSTRUCTOR

=over 4

=item new ( [ARGS] )

Creates an C<Nagios::MKLivestatus> object. C<new> takes at least the socketpath.
Arguments are in key-value pairs.

    socket                    path to the unix socket of check_mk livestatus
    verbose                   verbose mode
    line_seperator            ascii code of the line seperator, defaults to 10, (newline)
    column_seperator          ascii code of the column seperator, defaults to 0 (null byte)
    list_seperator            ascii code of the list seperator, defaults to 44 (comma)
    host_service_seperator    ascii code of the host/service seperator, defaults to 124 (pipe)

If the constructor is only passed a single argument, it is assumed to
be a the C<socket> specification.

=back

=cut

sub new {
    my $class = shift;
    unshift(@_, "socket") if scalar @_ == 1;
    my(%options) = @_;

    my $self = {
                    "verbose"                   => 0,
                    "socket"                    => undef,
                    "line_seperator"            => 10,   # defaults to newline
                    "column_seperator"          => 0,    # defaults to null byte
                    "list_seperator"            => 44,   # defaults to comma
                    "host_service_seperator"    => 124,  # defaults to pipe
               };
    bless $self, $class;

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
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


########################################

=head1 METHODS

=over 4

=item do

 do($statement)

 Send a single statement without fetching the result.
 Always returns true.

=cut

sub do {
    my $self      = shift;
    my $statement = shift;
    $self->_send($statement);
    return(1);
}


########################################

=item selectall_arrayref

 selectall_arrayref($statement)
 selectall_arrayref($statement, %opts)
 selectall_arrayref($statement, %opts, $limit )

 Sends a query and returns an array reference of arrays

    my $arr_refs = $nl->selectall_arrayref("GET hosts");

 to get an array of hash references do something like

    my $hash_refs = $nl->selectall_arrayref("GET hosts", { Slice => {} });

 to get an array of hash references from the first 2 returned rows only

    my $hash_refs = $nl->selectall_arrayref("GET hosts", { Slice => {} }, 2);

 use limit to limit the result to this number of rows

=cut

sub selectall_arrayref {
    my $self      = shift;
    my $statement = shift;
    my $opt       = shift;
    my $limit     = shift;

    # make opt hash keys lowercase
    %{$opt} = map { lc $_ => $opt->{$_} } keys %{$opt};

    my $result = $self->_send($statement);

    # trim result set down to excepted row count
    if(defined $limit and $limit >= 1) {
        if(scalar @{$result->{'result'}} > $limit) {
            @{$result->{'result'}} = @{$result->{'result'}}[0..$limit-1];
        }
    }

    if(defined $opt and ref $opt eq 'HASH' and exists $opt->{'slice'}) {
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


########################################

=item selectall_hashref

 selectall_hashref($statement, $key_field)

 Sends a query and returns a hashref with the given key

    my $hashrefs = $nl->selectall_hashref("GET hosts", "name");

=cut

sub selectall_hashref {
    my $self      = shift;
    my $statement = shift;
    my $key_field = shift;

    croak("key is required for selectall_hashref") if !defined $key_field;

    my $result = $self->selectall_arrayref($statement, { Slice => {} });

    my %indexed;
    for my $row (@{$result}) {
        croak("key $key_field not found in result set") if !defined $row->{$key_field};
        $indexed{$row->{$key_field}} = $row;
    }
    return(\%indexed);
}


########################################

=item selectcol_arrayref

 selectcol_arrayref($statement)
 selectcol_arrayref($statement, %opt )

 Sends a query an returns an arrayref for the first columns

    my $array_ref = $nl->selectcol_arrayref("GET hosts\nColumns: name");

    $VAR1 = [
              'localhost',
              'gateway',
            ];

 returns an empty array if nothing was found


 to get a different column use this

    my $array_ref = $nl->selectcol_arrayref("GET hosts\nColumns: name contacts", { Columns => [2] } );

 you can link 2 columns in a hash result set

    my %hash = @{$nl->selectcol_arrayref("GET hosts\nColumns: name contacts", { Columns => [1,2] } )};

    produces a hash with host the contact assosiation

    $VAR1 = {
              'localhost' => 'user1',
              'gateway'   => 'user2'
            };

=cut

sub selectcol_arrayref {
    my $self      = shift;
    my $statement = shift;
    my $opt       = shift;

    # make opt hash keys lowercase
    %{$opt} = map { lc $_ => $opt->{$_} } keys %{$opt};

    # if now colums are set, use just the first one
    if(!defined $opt->{'columns'} or ref $opt->{'columns'} ne 'ARRAY') {
        @{$opt->{'columns'}} = qw{1};
    }

    my $result = $self->selectall_arrayref($statement);

    my @column;
    for my $row (@{$result}) {
        for my $nr (@{$opt->{'columns'}}) {
            push @column, $row->[$nr-1];
        }
    }
    return(\@column);
}


########################################

=item selectrow_array

 selectrow_array($statement)

 Sends a query and returns an array for the first row

    my @array = $nl->selectrow_array("GET hosts");

 returns undef if nothing was found

=cut
sub selectrow_array {
    my $self      = shift;
    my $statement = shift;

    my @result = @{$self->selectall_arrayref($statement, {}, 1)};
    return @{$result[0]} if scalar @result > 0;
    return;
}


########################################

=item selectrow_arrayref

 selectrow_arrayref($statement)

 Sends a query and returns an array reference for the first row

    my $arrayref = $nl->selectrow_arrayref("GET hosts");

 returns undef if nothing was found

=cut
sub selectrow_arrayref {
    my $self      = shift;
    my $statement = shift;

    my @result = @{$self->selectall_arrayref($statement, {}, 1)};
    return $result[0] if scalar @result > 0;
    return;
}


########################################

=item selectrow_hashref

 selectrow_hashref($statement)

 Sends a query and returns a hash reference for the first row

    my $hashref = $nl->selectrow_hashref("GET hosts");

 returns undef if nothing was found

=cut
sub selectrow_hashref {
    my $self      = shift;
    my $statement = shift;

    my $result = $self->selectall_arrayref($statement, { Slice => {} }, 1);
    return $result->[0] if scalar @{$result} > 0;
    return;
}


########################################
# INTERNAL SUBS
########################################
sub _send {
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

    my ($recv, @result);
    chomp($statement);
    my $send = "$statement\nSeparators: $self->{'line_seperator'} $self->{'column_seperator'} $self->{'list_seperator'} $self->{'host_service_seperator'}\n";
    print "> ".Dumper($send) if $self->{'verbose'};
    print $sock $send;
    $sock->shutdown(1) or croak("shutdown failed: $!");
    while(<$sock>) { $recv .= $_; }
    print "< ".Dumper($recv) if $self->{'verbose'};
    close($sock);

    return if !defined $recv;

    my $line_seperator = chr($self->{'line_seperator'});
    my $col_seperator  = chr($self->{'column_seperator'});

    for my $line (split/$line_seperator/, $recv) {
        push @result, [ split/$col_seperator/, $line ];
    }

    # for querys with column header, no seperate columns will be returned
    my $keys;
    if($statement =~ m/^Columns: (.*)$/m) {
        my @keys = split/\s+/, $1;
        $keys = \@keys;
    } else {
        $keys = shift @result;
    }

    return({ keys => $keys, result => \@result});
}


1;

=back

=head1 SEE ALSO

For more information about the query syntax and the livestatus plugin installation
see the Livestatus page: http://mathias-kettner.de/checkmk_livestatus.html

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
