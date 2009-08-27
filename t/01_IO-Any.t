#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
#use Test::More tests => 10;
use Test::Differences;
use File::Spec;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
	use_ok ( 'IO::Any' ) or exit;
}

exit main();

sub main {
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
	
	return 0;
}

