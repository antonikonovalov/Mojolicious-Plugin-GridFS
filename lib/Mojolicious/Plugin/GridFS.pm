package Mojolicious::Plugin::GridFS;
use Mojo::Base 'Mojolicious::Plugin';
use Scalar::Util 'weaken';
use Mango;
use Mango::GridFS;
# use Mango::BSON 'bson_oid';
use Mojo::IOLoop;
use Data::Dump qw/dump/;

our $VERSION = '0.01';

has config => sub {+{}};

has 'writer';
has 'mango';
has 'fs';


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
	$config->{max_connections} = $config->{max_connections} || 5;

  	$p->config($config);

  	my $r = $p->config->{route};

  	# Emit "request" event early for requests that get upgraded to multipart
	$app->hook(after_build_tx => sub {
		my $tx = shift;
		weaken $tx;
		$tx->req->content->on(upgrade => sub { $tx->emit('request') });
	});

	my $auth_srt = ( ( $p->config->{user} and $p->config->{pwd} ) ?  $p->config->{user} . $p->config->{pwd} . '@' : '' );
	my $host = $p->config->{host}.':'. $p->config->{port};

	# this attr real need !!!!read - The reason for the attr approach is so that each child will init it's own MongoDB connection which is required by the MongoDB driver

	$app->attr( db => sub { 
    	Mango->new("mongodb://" . ( $p->config->{auth} ? $auth_srt : '' ) . $host . '/' . $p->config->{db} );
    });

	$app->helper( mango => sub { shift->app->db });

	$app->helper( fs => sub {
		$app->mango->db->gridfs;
	});

	#for Test
	# my $writer = $app->mango->db->gridfs->writer;
	# $writer->filename('bar.txt')->content_type('text/plain')->metadata({foo => 'bar'});
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
	warn '______________create___________________';
	my ($p,$self) = @_;


	my @oid = ();
	warn "STASH: ",  $self->stash('now_write_file');

	# if ( $self->stash('now_write_file') ) {

	#   		warn "__________close_writer___________";
	#   		my $writer = $self->stash($self->stash('now_write_file'));

	#   		my $oid = $writer->close( sub {
	#   			my ($w, $oid) = @_;
	#   			warn "_object id: $oid";
	#   			push @oid, $oid;
	#   			delete $self->stash->{$self->stash('now_write_file')};
	#   			delete $self->stash->{now_write_file};
	#   		});
	#  }

	# my $w = $self->mango->gridfs->writer;
	# $w->filename('foo.txt')->content_type('text/plain')->metadata({foo => 'bar'});
	# my $o = $w->write('hello ')->write('world!')->close;

	# warn $o;
	# First invocation, subscribe to "part" event to find the right one

	return $self->req->content->on(part => sub {
	  	my ($multi, $single) = @_;

	  	warn "__________________PART";

	  	if ( $self->stash('now_write_file') ) {

	  		warn "__________close_writer___________";
	  		my $writer = $self->stash($self->stash('now_write_file'));

	  		my $oid = $writer->close;#( sub {
	  			# my ($w, $oid) = @_;
	  			warn "_object id: $oid";
	  			push @oid, $oid;
	  			delete $self->stash->{$self->stash('now_write_file')};
	  			delete $self->stash->{now_write_file};
	  		# });
	  	}

	  	warn "_____________________________________________", $self->stash('now_write_file');

	  	$single->on(body => sub {
			my $single = shift;
		
			warn "__________________BODY";
			# if ($single->headers->content_disposition =~ /filename="([^"]+)"/) {
		 #  		warn "BODY ", $1;
	  # 		}

			# if ( $self->stash('now_write_file') ) {

		 #  		warn "__________close_writer___________";
		 #  		my $writer = $self->stash($self->stash('now_write_file'));

		 #  		my $oid = $writer->close( sub {
		 #  			my ($w, $oid) = @_;
		 #  			warn "_object id: $oid";
		 #  			push @oid, $oid;
		 #  			delete $self->stash->{$self->stash('now_write_file')};
		 #  			delete $self->stash->{now_write_file};
		 #  		});
		 #  	}


			# Make sure we have the right part and replace "read" event
			return unless $single->headers->content_disposition =~ /filename="([^"]+)"/;

			$self->app->log->debug($1 . ' now read.');
			$self->stash( now_write_file => $1);
			$self->stash("$1" => $self->mango->db->gridfs->writer->filename($1)->content_type('text/plain')->metadata({foo => 'bar'}));
			warn "WRITE OBJ: ", $self->stash($1);

			$single->unsubscribe('read')->on(read => sub {
				warn "__________________READ";
		  		my ($single, $bytes) = @_;
		  		#read every chunk
		  		my $writer = $self->stash($self->stash('now_write_file'));
				warn "CURRENT WRITER IS CLOSED  FOR " . $self->stash('now_write_file') . "? - ", ( $writer->is_closed ? 'YES' : 'NO');
		  		$writer->write($bytes);
		  		# Log size of every chunk we receive
		  		$self->app->log->debug(length($bytes) . ' bytes uploaded.');
			});
	  	});
	}) unless $self->req->is_finished;

	# Second invocation, render response

	warn "!!!!!!!FINISH!!!!!!!!", dump @oid;

	$self->render(text => 'Upload was successful.');
}

sub _read {
	return 1;
}

sub _list {
	my ($p,$self) = @_;
	$self->render_later;

	#!!!!!!! non bloking !!!!!!!
	$self->fs->list(sub {
		my ($gridfs, $err, $names) = @_;

		$self->render(json => ($names ? { data  => { files => $names }, ok => 1 }:  { msg => {error => $err }, ok => 0 }) );
	});
}

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

