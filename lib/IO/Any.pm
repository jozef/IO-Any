package IO::Any;

=head1 NAME

IO::Any - open anything

=head1 SYNOPSIS

    # NOTE commented out lines doesn't work (jet)
    use IO::Any;

    $fh = IO::Any->read('filename');
    $fh = IO::Any->read('file://var/log/syslog');
    #$fh = IO::Any->read('http://search.cpan.org/');
    #$fh = IO::Any->read('-');
    $fh = IO::Any->read(['folder', 'other-folder', 'filename']);
    $fh = IO::Any->read('folder');
    $fh = IO::Any->read("some text\nwith more lines\n");
    $fh = IO::Any->read(\"some text\nwith more lines\n");
    $fh = IO::Any->read('{"123":[1,2,3]}');
    $fh = IO::Any->read('<root><element>abc</element></root>');
    #$fh = IO::Any->read(IO::String->new("cba"));
    #$fh = IO::Any->read($object_with_toString_method);

    $fh = IO::Any->write('filename');
    $fh = IO::Any->write('file://var/log/syslog');
    #$fh = IO::Any->write('-');
    $fh = IO::Any->write(['folder', 'filename']);
    #$fh = IO::Any->write('=');
    my $string;
    $fh = IO::Any->write(\$string);

    my $content = IO::Any->slurp(['folder', 'filename']);
    IO::Any->spew(['folder2', 'filename'], $content);

    perl -MIO::Any -le 'print IO::Any->slurp("/etc/passwd")'
    perl -MIO::Any -le 'IO::Any->spew("/tmp/timetick", time())'

=head1 DESCRIPTION

The aim is to provide read/write anything. The module tries to guess
C<$what> the "anything" is based on some rules. See C</new> method Pod for
examples and C</new> and C</_guess_what> code for the implementation.

There are two methods C</slurp> and C</spew> to read/write whole C<$what>.

=cut

use warnings;
use strict;

our $VERSION = '0.02';

use 5.010;

use Carp 'croak';
use Scalar::Util 'blessed';
use IO::String;
use IO::File;
use File::Spec;

=head1 METHODS

=head2 new($what, $how)

Open C<$what> in C<$how> mode.

C<$what> can be:

		'filename'                => [ 'file' => 'filename' ],
		'folder/filename'         => [ 'file' => 'folder/filename' ],
		'file:///folder/filename' => [ 'file' => '/folder/filename' ],
		[ 'folder', 'filename' ]  => [ 'file' => File::Spec->catfile('folder', 'filename') ],
		'http://a/b/c'            => [ 'http' => 'http://a/b/c' ],
		'https://a/b/c'           => [ 'http' => 'https://a/b/c' ],
		'{"123":[1,2,3]}'         => [ 'string' => '{"123":[1,2,3]}' ],
		'[1,2,3]'                 => [ 'string' => '[1,2,3]' ],
		'<xml></xml>'             => [ 'string' => '<xml></xml>' ],
		"a\nb\nc\n"               => [ 'string' => "a\nb\nc\n" ],    

Returns filehandle. L<IO::String> for 'string', L<IO::File> for 'file'.
'http' not implemented jet :)

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
        when ('file')   {
            my $fh = IO::File->new;
            $fh->open($proper_what, $how)
                or croak 'error opening file "'.$proper_what.'" - '.$!;
            return $fh;
        }
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
        when ('ARRAY')  { return ('file', File::Spec->catfile(@{$what})) }
        when ('SCALAR') { return ('string', $what) }
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


=head2 read($what)

Same as C<<IO::Any->new($what, '<');>> or C<<IO::Any->new($what);>>.

=cut

sub read {
    my $class = shift;
    my $what  = shift;
    croak 'too many arguments'
        if @_;
    
    return $class->new($what, '<');
}


=head2 write($what)

Same as C<<IO::Any->new($what, '>');>>

=cut

sub write {
    my $class = shift;
    my $what  = shift;
    croak 'too many arguments'
        if @_;
    
    return $class->new($what, '>');
}


=head2 slurp($what)

Returns content of C<$what>.

=cut

sub slurp {
    my $class = shift;
    my $what  = shift;
    croak 'too many arguments'
        if @_;
    
    my $fh = $class->read($what);
    return do { local $/; <$fh> };
}


=head2 spew($what, $data)

Writes C<$data> to C<$what>.

=cut

sub spew {
    my $class = shift;
    my $what  = shift;
    my $data  = shift;
    croak 'too many arguments'
        if @_;
    
    my $fh = $class->write($what);
    return $fh->print($data);
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
