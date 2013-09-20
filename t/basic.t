use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'GridFS';

my $t = Test::Mojo->new;

# $t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');

done_testing();
