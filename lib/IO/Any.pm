package IO::Any;

=head1 NAME

IO::Any - open anything

=head1 SYNOPSIS

    use IO::Any;

    $fh = IO::Any->read('filename');
    $fh = IO::Any->read('file://var/log/syslog');
    $fh = IO::Any->read('http://search.cpan.org/');
    $fh = IO::Any->read('-');
    $fh = IO::Any->read(['folder', 'other-folder', 'filename']);
    $fh = IO::Any->read('folder');
    $fh = IO::Any->read("some text\nwith more lines\n");
    $fh = IO::Any->read(\"some text\nwith more lines\n");
    $fh = IO::Any->read('{"123":[1,2,3]}');
    $fh = IO::Any->read('<root><element>abc</element></root>');
    $fh = IO::Any->read(IO::String->new("cba"));
    $fh = IO::Any->read($object_with_toString_method);

    $fh = IO::Any->write('filename');
    $fh = IO::Any->write('file://var/log/syslog');
    $fh = IO::Any->write('-');
    $fh = IO::Any->write(['folder', 'filename']);
    $fh = IO::Any->write('=');
    my $string;
    $fh = IO::Any->write(\$string);

=head1 NOTE

This is an experiment :-)

=head1 DESCRIPTION

=cut

use warnings;
use strict;

our $VERSION = '0.01';

use 5.010;

use Carp 'croak';
use Scalar::Util 'blessed';
use IO::String;
use File::Spec;

=head1 METHODS

=head2 new()

=cut

sub new {
    my $class = shift;
    my $what  = shift;
    my $how   = shift || '<';
    croak 'too many arguments'
        if @_;
    
    my ($type, $proper_what) = $class->_guess_what($what);
    
    given ($type) {
        when ('string') { return IO::String->new($proper_what) }
        when ('file')   { open(my $fh, $how, $proper_what) or die $!; return $fh }
        when ('http')   { die 'no http support jet :-|' }
    }
}


=head2 _guess_what

Returns ($type, $what). $type can be:

    file
    string
    http

C<$what> is normalized path that can be used for IO::*.

=cut

sub _guess_what {
    my $class = shift;
    my $what  = shift;
    
    if (blessed $what) {
        return 'no blessed support jet';
    }
    
    given (ref $what) {
        when ('ARRAY') { return ('file', File::Spec->catfile(@{$what})) }
        when ('')      {} # do nothing here if not reference
        default { croak 'no support for ref '.(ref $what) }
    }
    
    given ($what) {
        when (m{^file://(.+)$}) { return ('file', $1) }              # local file
        when (m{^https?://})    { return ('http', $what) }           # http link
        when (m{^<})            { return ('string', $what) }         # xml string
        when (m(^{))            { return ('string', $what) }         # json string
        when (m{^\[})           { return ('string', $what) }         # json string
        when (m{\n[\s\w]})      { return ('string', $what) }         # multi-line string
        default                 { return ('file', $what) }           # default is filename
    }
}

sub read {
    my $class = shift;
    my $what  = shift;
    croak 'too many arguments'
        if @_;
    
    return $class->new($what, '<');
}
sub write {
    my $class = shift;
    my $what  = shift;
    croak 'too many arguments'
        if @_;
    
    return $class->new($what, '>');
}

1;


__END__

=head1 AUTHOR

Jozef Kutej, C<< <jkutej at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-io-any at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=IO-Any>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc IO::Any


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=IO-Any>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/IO-Any>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/IO-Any>

=item * Search CPAN

L<http://search.cpan.org/dist/IO-Any>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of IO::Any
