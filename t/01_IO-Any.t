#!/usr/bin/perl

use strict;
use warnings;

#use Test::More 'no_plan';
use Test::More tests => 17;
use Test::Differences;
use File::Spec;
use File::Temp 'tempdir';
use File::Slurp 'read_file';

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
	use_ok ( 'IO::Any' ) or exit;
}

exit main();

sub main {
	my $tmpdir = tempdir( CLEANUP => 1 );

	my @riddles = (
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
	);
	
	while (my ($question, $answer) = splice(@riddles,0,2)) {
		eq_or_diff([ IO::Any->_guess_what($question) ], $answer, 'guess what is "'.$question.'"')
	}
	
	isa_ok(IO::Any->read([$Bin, 'stock', '01.txt']), 'IO::File', 'IO::Any->read([])');
	isa_ok(IO::Any->read('{}'), 'IO::String', 'IO::Any->read("{}")');
	
	eq_or_diff(
		[ IO::Any->slurp([$Bin, 'stock', '01.txt']) ],
		[ qq{1\n22\n333\n} ],
		'[ IO::Any->slurp() ]'
	);
	eq_or_diff(
		scalar IO::Any->slurp([$Bin, 'stock', '01.txt']),
		qq{1\n22\n333\n},
		'scalar IO::Any->slurp()'
	);
	
	IO::Any->spew([$tmpdir, '01-test.txt'], qq{4\n55\n666\n});
	eq_or_diff(
		scalar read_file(File::Spec->catfile($tmpdir, '01-test.txt')),
		qq{4\n55\n666\n},
		'IO::Any->spew()'
	);
	my $str;
	IO::Any->spew(\$str, qq{1\n22\n333\n});
	eq_or_diff(
		$str,
		qq{1\n22\n333\n},
		'IO::Any->spew(\$str)'
	);
	
	return 0;
}

