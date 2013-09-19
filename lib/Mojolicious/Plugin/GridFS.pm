package Mojolicious::Plugin::GridFS;
use Mojo::Base 'Mojolicious::Plugin';
use Scalar::Util 'weaken';
use Mango;

our $VERSION = '0.01';

has config => sub {+{}};

sub register {
  	my ($p, $app, $config) = @_;

  	$config->{url_base} = $config->{url_base} || 'fs';
  	$config->{route} = $config->{route} || $app->routes;
  	$config->{crud_names} = $config->{crud_names} || {
		create => 'upload',
		read => 'download',
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

  	my $mango  = Mango->new("mongodb://$p->config->{host}:$p->config->{port}");
	my $gridfs = $mango->db->gridfs;

	$app->helper(fs => $gridfs);

  	$r->get("/$p->config/files" => _list );
  	$r->get("/$p->config/files/:object_id" => _read );
  	$r->post("/$p->config/files" => _create );
  	# $r->put("/$p->config/files/:object_id" => _update );
  	$r->delete("/$p->config/files/:object_id" => _delete );

}

sub _create {
	my $self = shift;

	# First invocation, subscribe to "part" event to find the right one
	my ($writer, @oid);
	return $self->req->content->on(part => sub {
	  	my ($multi, $single) = @_;

	  	if ($writer) {
	  		push @iod, $writer->close;
	  	}
	  	#open writer
	  	# Subscribe to "body" event of part to make sure we have all headers
	  	$single->on(body => sub {
			my $single = shift;

			$writer = $self->fs->writer->filename($single->filename);		
			# Make sure we have the right part and replace "read" event
			# return unless $single->headers->content_disposition =~ /[\w\d]+/;
			$single->unsubscribe('read')->on(read => sub {
		  		my ($single, $bytes) = @_;
		  		#read every chunk
		  		$writer->write($bytes);
		  		# Log size of every chunk we receive
		  		$self->app->log->debug(length($bytes) . ' bytes uploaded.');
			});
	  	});
	}) unless $self->req->is_finished;

	# Second invocation, render response
	$self->render(json => {ids => \ @iod });
	$self->render(text => 'Upload was successful.');
}

sub _read {

}

sub _list {
	my $self = shift;
	$self->render_later;

	$self->fs->list(sub {
		my ($gridfs, $err, $names) = @_;
		$self->render(json => $names);
	});
}

# sub _update {
	
# }

sub _delete {
	
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

