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
    $fh = IO::Any->read(*DATA);
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
C<$what> the "anything" is based on some rules. See L</new> method Pod for
examples and L</new> and L</_guess_what> code for the implementation.

There are two methods L</slurp> and L</spew> to read/write whole C<$what>.

=head1 MOTIVATION

The purpose is to be able to write portable one-liners (both commandline
and inside program) to read/write/slurp/spew files/strings/$what-ever.
As I'm sick of writing C<< File::Spec->catfile('folder', 'filename')  >>
or C<< use Path::Class; dir(); file(); >>.

First time I've used L<IO::Any> for L<JSON::Util> where for the function
to encode and decode files I can just say put as an argumen anything that
L<IO::Any> accepts. It's then up to the users of that module to pass an array
if it's a file, scalar ref if it is a string or relay on the module to
guess $what.

Any suggestions, questions and also demotivations are more than welcome!

=cut

use warnings;
use strict;

our $VERSION = '0.04';

use 5.010;

use Carp 'croak';
use Scalar::Util 'blessed';
use IO::String;
use IO::File;
use IO::AtomicFile;
use File::Spec;
use Fcntl qw(:flock);

=head1 METHODS

=head2 new($what, $how, $options)

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

Here are alvailable C<%$options> options:

    atomic    true/false if the file operations should be done using L<IO::AtomicFile> or L<IO::File>
    LOCK_SH   lock file for shared access
    LOCK_EX   lock file for exclusive
    LOCK_NB   lock file non blocking (will throw an excpetion if file is
                  already locked, instead of blocking the process)

=cut

sub new {
    my $class = shift;
    my $what  = shift;
    my $how   = shift || '<';
    my $opt   = shift || {};
    croak 'too many arguments'
        if @_;
    
    croak 'expecting hash ref'
        if ref $opt ne 'HASH';
    foreach my $key (keys %$opt) {
        croak 'unknown option '.$key
            if (not $key ~~ ['atomic', 'LOCK_SH', 'LOCK_EX', 'LOCK_NB']);
    }
    
    my ($type, $proper_what) = $class->_guess_what($what);
    
    given ($type) {
        when ('string') { return IO::String->new($proper_what) }
        when ('file')   {
            my $fh = $opt->{'atomic'} ? IO::AtomicFile->new() : IO::File->new();
            $fh->open($proper_what, $how)
                or croak 'error opening file "'.$proper_what.'" - '.$!;
            
            # locking if requested
            if ($opt->{'LOCK_SH'} or $opt->{'LOCK_EX'}) {
                flock($fh,
                    ($opt->{'LOCK_SH'} ? LOCK_SH : 0)
                    | ($opt->{'LOCK_EX'} ? LOCK_EX : 0)
                    | ($opt->{'LOCK_NB'} ? LOCK_NB : 0)
                ) or croak 'flock failed - '.$!;
            }
            
            return $fh;
        }
        when ('iofile')   { return $proper_what }
        when ('iostring') { return $proper_what }
        when ('http')     { die 'no http support jet :-|' }
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
    
    given (blessed $what) {
        when (undef) {}            # not blessed, do nothing
        when ('Path::Class::File') { $what = $what->stringify }
        when (['IO::File', 'IO::AtomicFile']) {
            croak 'passed unopened IO::File'
                if not $what->opened;
            return ('iofile', $what);
        }
        when ('IO::String')        { return ('iostring', $what) }
        default { croak 'no support for '.$_ };
    }
    
    given (ref $what) {
        when ('ARRAY')  { return ('file', File::Spec->catfile(@{$what})) }
        when ('SCALAR') { return ('string', $what) }
        when ('')      {} # do nothing here if not reference
        default { croak 'no support for ref '.(ref $what) }
    }
    
    # check for typeglobs
    if ((ref \$what eq 'GLOB') and (my $fh = *{$what}{IO})) {
        return ('iofile', $fh);
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

Same as C<< IO::Any->new($what, '<'); >> or C<< IO::Any->new($what); >>.

=cut

sub read {
    my $class = shift;
    my $what  = shift;
    my $opt   = shift;
    croak 'too many arguments'
        if @_;
    
    return $class->new($what, '<', $opt);
}


=head2 write($what)

Same as C<< IO::Any->new($what, '>'); >>

=cut

sub write {
    my $class = shift;
    my $what  = shift;
    my $opt   = shift;
    croak 'too many arguments'
        if @_;
    
    return $class->new($what, '>', $opt);
}


=head2 slurp($what)

Returns content of C<$what>.

If L<AnyEvent> is loaded then uses event loop to read the content.

=cut

sub slurp {
    my $class = shift;
    my $what  = shift;
    my $opt   = shift;
    croak 'too many arguments'
        if @_;
    
    my $fh = $class->read($what, $opt);
    
    # use event loop when AnyEvent is loaded (skip IO::String, doesn't work and makes no sense)
    if ($INC{'AnyEvent.pm'} and not $fh->isa('IO::String')) {
        eval 'use AnyEvent::Handle'
            if not $INC{'AnyEvent/Handle.pm'};
        my $eof = AnyEvent->condvar;
        my $content = '';
        my $hdl = AnyEvent::Handle->new(
            fh      => $fh,
            on_read => sub {
                $content .= delete $_[0]->{'rbuf'};
            },
            on_eof  => sub {
                $eof->send;
            },
            on_error => sub {
                my ($hdl, $fatal, $msg) = @_;
                $hdl->destroy;
                $eof->croak($msg);
            }
        );

        $eof->recv;
        $hdl->destroy;
        close $fh;
        return $content;
    }
    
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;    
}


=head2 spew($what, $data, $opt)

Writes C<$data> to C<$what>.

If L<AnyEvent> is loaded then uses event loop to write the content.

=cut

sub spew {
    my $class = shift;
    my $what  = shift;
    my $data  = shift;
    my $opt   = shift;
    croak 'too many arguments'
        if @_;
    
    # "parade" to allow safe locking
    my $fh = $class->new($what, '+>>', $opt);
    $fh->seek(0,0);
    $fh->truncate(0);

    # use event loop when AnyEvent is loaded (skip IO::String, doesn't work and makes no sense)
    if ($INC{'AnyEvent.pm'} and not $fh->isa('IO::String')) {
        eval 'use AnyEvent::Handle'
            if not $INC{'AnyEvent/Handle.pm'};
        
        my $eof = AnyEvent->condvar;
        my $hdl = AnyEvent::Handle->new(
            fh       => $fh,
            on_drain => sub {
                $eof->send;
            },
            on_error => sub {
                my ($hdl, $fatal, $msg) = @_;
                $hdl->destroy;
                $eof->croak($msg);
            }
        );
        
        $hdl->push_write($data);

        $eof->recv;
        $hdl->destroy;
        close $fh;
        return;
    }

    print $fh $data;
    $fh->close || croak 'failed to close file - '.$!;
    return;
}

1;


__END__

=head1 SEE ALSO

L<IO::All>, L<File::Spec>, L<Path::Class>

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

=item * GitHub: issues

L<http://github.com/jozef/IO-Any/issues>

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
