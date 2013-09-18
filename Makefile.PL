use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::Mojolicious-Plugin-GridFS',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Mojolicious-Plugin-GridFS.pm',
  AUTHOR       => 'A Good Programmer <nospam@cpan.org>',
  PREREQ_PM    => {'Mojolicious' => '4.39'},
  test         => {TESTS => 't/*.t'}
);
