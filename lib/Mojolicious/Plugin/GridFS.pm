package Mojolicious::Plugin::GridFS;
use Mojo::Base 'Mojolicious::Plugin';
use Scalar::Util 'weaken';
use Mango;
use Mango::BSON  qw/bson_oid/;
use Mojo::IOLoop;
use Data::Dump qw/dump/;

our $VERSION = '0.01';

has config => sub {+{}};

sub register {
  	my ($p, $app, $config) = @_;

  	$config->{user} = $config->{user} || 'Anton';
  	$config->{pwd} = $config->{pwd} || 1234;
  	$config->{auth} = $config->{auth} || 0;
  	$config->{db} = $config->{db} || 'mango';
  	$config->{url_base} = $config->{url_base} || 'fs';
  	$config->{route} = $config->{route} || $app->routes;

  	$ENV{MOJO_MAX_MESSAGE_SIZE} = 1073741824;

  	$config->{crud_names} = $config->{crud_names} || {
		create => 'upload',
		read => 'download',
		list => 'list',
		update => 'reload',
		delete => 'remove'
	};

	$config->{host} = $config->{host} || 'localhost';
	$config->{port} = $config->{port} || 27017;
	$config->{max_connections} = $config->{max_connections} || 1000;

  	$p->config($config);

  	my $r = $p->config->{route};

  	# Emit "request" event early for requests that get upgraded to multipart
	$app->hook(after_build_tx => sub {
		my $tx = shift;
		weaken $tx;
		$tx->req->content->on(upgrade => sub { $tx->emit('request') });
	});

	my $auth_srt = ( ( $p->config->{user} and $p->config->{pwd} ) ?  $p->config->{user} .':'. $p->config->{pwd} . '@' : '' );
	my $host = $p->config->{host}.':'. $p->config->{port};
	warn $auth_srt,'',$host;

	# this attr real need !!!!read - The reason for the attr approach is so that each child will init it's own MongoDB connection which is required by the MongoDB driver

	$app->attr( mongodb => sub { 
    	my $mango = Mango->new("mongodb://" . ( $p->config->{auth} ? $auth_srt : '' ) . $host . '/' . $p->config->{db} );
    	$mango->max_connections($p->config->{max_connections}) if $p->config->{max_connections};
    	$mango;
    });

	$app->helper( mango => sub { shift->app->mongodb });

	$app->helper( fs => sub {
		$app->mango->db->gridfs;
	});

  	$r->get("/" . $p->config->{url_base} . "/files" => sub {
  		my $self = shift;
  		$self->render_later;
  		$p->_list($self);
  	})->name($p->config->{crud_names}->{list});

  	$r->get("/" . $p->config->{url_base} . "/files/:object_id" => sub {
  		my $self = shift;
  		$self->render_later;
  		$p->_read($self);
  	})->name($p->config->{crud_names}->{read});

  	$r->post("/" . $p->config->{url_base} . "/files" => sub {
  		my $self = shift;
  		$self->render_later;
  		$p->_create($self);
  	})->name($p->config->{crud_names}->{create});

  	$r->delete("/" . $p->config->{url_base} . "/files/:object_id" => sub {
  		my $self = shift;
  		$self->render_later;
  		$p->_delete($self);
  	})->name($p->config->{crud_names}->{delete});

}

sub _create {
	my ($p,$c) = @_;

	Mojo::IOLoop->stream($c->tx->connection)->timeout(300);
	unless($c->stash('oids')) {
		$c->stash(oids => []);
	}

	$c->req->on(finish => sub {
		my $req = shift;

		my $writer = $c->stash($c->stash('now_write_file'));

		if ( $writer && !$writer->is_closed ) {
			$writer->close(sub {
	  			my ($w, ,$err, $oid) = @_;

	  			warn "_on_finish err in close : $err" if $err;

	  			my $oids = $c->stash('oids');

	  			push (@$oids, {
	  				_id => {
	  					'$oid' => $oid
	  				},
  					filename => $w->filename,
  					chunkSize => $w->chunk_size,
  					contentType => $w->content_type,
	  			});

	  			if ($c->stash('now_write_file')) {
		  			delete $c->stash->{$c->stash('now_write_file')} if $c->stash->{$c->stash('now_write_file')};
					delete $c->stash->{now_write_file};
	  			}

				delete $c->stash->{oids};

	  			$c->render(json => {
					ok => 1,
					data => $oids
				});
			});
		}
	});

	# First invocation, subscribe to "part" event to find the right one

	return $c->req->content->on(part => sub {
	  	my ($multi, $single) = @_;

	  	if ( $c->stash('now_write_file') ) {
	  		my $writer = $c->stash($c->stash('now_write_file'));

	  		$writer->close( sub {
	  			my ($w, ,$err, $oid) = @_;

	  			warn "_err in close : $err" if $err;
	  			warn "_object id: $oid";
	  			my $oids = $c->stash('oids');

	  			push (@$oids, {
	  				_id => {
	  					'$oid' => $oid
	  				},
  					filename => $w->filename,
  					chunkSize => $w->chunk_size,
  					contentType => $w->content_type,
	  			});

	  			$c->stash(oids  => $oids );

	  			if ($c->stash('now_write_file')) {
		  			delete $c->stash->{$c->stash('now_write_file')} if $c->stash->{$c->stash('now_write_file')};
		  			delete $c->stash->{now_write_file};
	  			}
	  		});
	  	}

	  	$single->on(body => sub {
			my $s = shift;

			# Make sure we have the right part and replace "read" event
			return unless $s->headers->content_disposition =~ /filename="([^"]+)"/;

			$c->app->log->debug($1 . ' now read.');
			$c->stash( now_write_file => $1);
			$c->stash("$1" => $c->mango->db->gridfs->writer
				->filename($1)
				->content_type($s->headers->content_type)
				->metadata($s->headers->to_hash)
			);

			$single->unsubscribe('read')->on(read => sub {
		  		my ($single, $bytes) = @_;
		  		#read every chunk
		  		my $writer = $c->stash($c->stash('now_write_file'));
		  		if ($writer) {
		  			$writer->write($bytes => sub {
		  				my ($w, $err) = @_;

		  				if ($err) {
		  					warn "!!! ERROR: ", $err,dump $c->stash;
		  				}
		  			});
		  			# Log size of every chunk we receive
		  			$c->app->log->debug(length($bytes) . ' bytes uploaded.');
		  		} else {
		  			warn "!!! ERROR NO WRITER: ", dump $c->stash;
		  		}
			});
	  	});
	}) unless $c->req->is_finished;
}

sub _read {
	my ($p,$c) = @_;
	my $oid = bson_oid( $c->stash('object_id') );
	$c->app->log->debug("download $oid");

	# !!!!!!! non bloking mode!!!!!!!
	$c->fs->reader->open($oid => sub {
		my ($reader, $err) = @_;
		my $filename = $reader->filename;
		my $content_type = $reader->content_type;
			
		if (!$err) {
			$reader->slurp(sub {
				my ($reader, $err, $data) = @_;

				if ($err) {
					$c->render(json => {
						ok => 0,
						msg => $err
					});
				} else {
	        		$c->res->content->headers->add( 'Content-Type', "$content_type;name=$filename");
	        		$c->res->content->headers->add( 'Content-Disposition',"attachment;filename=$filename" );
					$c->render( data => $data );
				}
			});
		} else {
			$c->render(json => {
				ok => 0,
				msg => $err
			});
		}
	});
}

sub _list {
	my ($p,$self) = @_;

	#!!!!!!! non bloking mode!!!!!!!
	$self->fs->list(sub {
		my ($gridfs, $err, $names) = @_;

		$self->render(json => ($names ? { data  => { files => $names }, ok => 1 }:  { msg => {error => $err }, ok => 0 }) );
	});
}

sub _delete {
	my ($p,$c) = @_;
	my $oid = bson_oid( $c->stash('object_id') );

	#!!!!!!! non bloking mode!!!!!!!
	$c->fs->delete($oid => sub {
    my ($gridfs, $err) = @_;
    	$c->render(json => (!$err ? { msg => 'was deleted', ok => 1 } : { msg => $err, ok => 0 }) );
  	});
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

