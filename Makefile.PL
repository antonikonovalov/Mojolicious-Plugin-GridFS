use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  	NAME         => 'Mojolicious::Plugin::GridFS',
  	VERSION_FROM => 'lib/Mojolicious/Plugin/GridFS.pm',
  	AUTHOR       => 'a.konovalov <a.konovalov@cpan.org>',
  	PREREQ_PM    => {
  		'Mojolicious' => '4.39',
  		'Mango' => '0.12',
  	},
  	# test         => {TESTS => 't/*.t'}
);
