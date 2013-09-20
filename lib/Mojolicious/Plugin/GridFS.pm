package Mojolicious::Plugin::GridFS;
use Mojo::Base 'Mojolicious::Plugin';
use Scalar::Util 'weaken';
use Mango;
use Mango::BSON 'bson_oid';
use Mojo::IOLoop;
use Data::Dump qw/dump/;

our $VERSION = '0.01';

has config => sub {+{}};

sub register {
  	my ($p, $app, $config) = @_;

  	$config->{user} = $config->{user} || 'Anton';
  	$config->{pwd} = $config->{pwd} || 1234;
  	$config->{db} = $config->{db} || 'fs';
  	$config->{url_base} = $config->{url_base} || 'fs';
  	$config->{route} = $config->{route} || $app->routes;

  	$config->{crud_names} = $config->{crud_names} || {
		create => 'upload',
		read => 'download',
		list => 'list',
		update => 'reload',
		delete => 'remove'
	};

	$config->{host} = $config->{host} || 'localhost';
	$config->{port} = $config->{port} || 27017;
	$config->{max_connections} = $config->{max_connections} || 5;

  	$p->config($config);

  	my $r = $p->config->{route};

  	# Emit "request" event early for requests that get upgraded to multipart
	$app->hook(after_build_tx => sub {
		my $tx = shift;
		weaken $tx;
		$tx->req->content->on(upgrade => sub { $tx->emit('request') });
	});

	$app->helper(mango => sub {
		Mango->new("mongodb://".( ($p->config->{user} and $p->config->{pwd}) ?  $p->config->{user} . $p->config->{pwd} . '@' : '') . $p->config->{host}.':'. $p->config->{port} . '/' . $p->config->{db});
	});

	$app->helper(fs => sub {
		$app->mango->db->gridfs;
	});

	#for Test
	# my $writer = $gridfs->writer;
	# $writer->filename('foo.txt')->content_type('text/plain')->metadata({foo => 'bar'});
	# my $oid = $writer->write('hello ')->write('world!')->close;
	# warn $oid;

  	$r->get("/" . $p->config->{url_base} . "/files" => sub { $p->_list(shift) } )
  		->name($p->config->{crud_names}->{list});
  	$r->get("/" . $p->config->{url_base} . "/files/:object_id" => sub { $p->_read(shift) } )
  		->name($p->config->{crud_names}->{read});
  	$r->post("/" . $p->config->{url_base} . "/files" => sub { $p->_create(shift) } )
  		->name($p->config->{crud_names}->{create});
  	# $r->put("/$p->config->{url_base}/files/:object_id" => _update );
  	$r->delete("/" . $p->config->{url_base} . "/files/:object_id" => sub { $p->_delete(shift) } )
  		->name($p->config->{crud_names}->{delete});

}

sub _create {
	my ($p,$self) = @_;

	# my $w = $self->mango->gridfs->writer;
	# $w->filename('foo.txt')->content_type('text/plain')->metadata({foo => 'bar'});
	# my $o = $w->write('hello ')->write('world!')->close;

	# warn $o;
	warn '_create';
	# First invocation, subscribe to "part" event to find the right one
	my ($writer, @oid) = ( 0, ());

	return $self->req->content->on(part => sub {
	  	my ($multi, $single) = @_;

	  	if ($writer) {
	  		warn "_close_write_ $writer";
	  		$writer = 0;
	  		# $writer->close(sub {
	  		# 	my ($w, $oid) = @_;
	  		# 	push @oid, $oid;
	  		# 	warn "_object id: $oid";
	  		# 	$writer = 0;
	  		# });
	  	}

	  	$single->on(body => sub {
			my $single = shift;

			# Make sure we have the right part and replace "read" event
			return unless $single->headers->content_disposition =~ /filename="([^"]+)"/;
			$self->app->log->debug($1 . ' now read.');
			$writer = $self->fs->writer->filename($1);
			warn "WRITE OBJ: $writer";

			$single->unsubscribe('read')->on(read => sub {
		  		my ($single, $bytes) = @_;

		  		#read every chunk
		  		warn "WRITE NEXT CHUNCK: ",$writer->write($bytes);
		  		# Log size of every chunk we receive
		  		$self->app->log->debug(length($bytes) . ' bytes uploaded.');
			});
	  	});
	}) unless $self->req->is_finished;

	# Second invocation, render response

	warn "!!!!!!!FINISH!!!!!!!!", dump @oid;

	# $self->render(json => {ids => \ @oid });

	$self->render(text => 'Upload was successful.');
}

sub _read {
	return 1;
}

sub _list {
	my ($p,$self) = @_;
	warn "list";
	$self->render_later;

	$self->fs->list(sub {
		my ($gridfs, $err, $names) = @_;
		$self->render(json => $names);
	});

	$self->render(json => $self->fs->list);
}

# sub _update {
	
# }

sub _delete {
	return 1;
}

1;
__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::GridFS - Mojolicious Plugin

=head1 SYNOPSIS

 	# Mojolicious
  	$self->plugin('GridFS',{
		url_base => 'gridfs',
		route => $app->routes,
		crud_names => {
			create => 'upload',
			read => 'download',
			update => 'reload',
			delete => 'remove'
		},
		host => 'localhost',
		port => 27017,
		max_connections => 5,
  	});

  	# Mojolicious::Lite
  	plugin 'Mojolicious-Plugin-GridFS';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Mojolicious-Plugin-GridFS> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::Mojolicious-Plugin-GridFS> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut

