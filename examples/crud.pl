use Mojolicious::Lite;
use lib '../lib';

plugin 'GridFS';
# use Scalar::Util 'weaken';

  # Emit "request" event early for requests that get upgraded to multipart
# hook after_build_tx => sub {
# 	my $tx = shift;
# 	weaken $tx;
# 	$tx->req->content->on(upgrade => sub { $tx->emit('request') });
# };

  # Upload form in DATA section
get '/' => 'index';

 # Streaming multipart upload (invoked twice, due to early "request" event)
 # это как раз будет в плагине
# post '/upload' => sub {
# 	my $self = shift;

# 	# First invocation, subscribe to "part" event to find the right one
# 	return $self->req->content->on(part => sub {
# 	  my ($multi, $single) = @_;

# 	  # Subscribe to "body" event of part to make sure we have all headers
# 	  $single->on(body => sub {
# 		my $single = shift;

# 		# Make sure we have the right part and replace "read" event
# 		return unless $single->headers->content_disposition =~ /example/;
# 		$single->unsubscribe('read')->on(read => sub {
# 		  my ($single, $bytes) = @_;

# 		  # Log size of every chunk we receive
# 		  $self->app->log->debug(length($bytes) . ' bytes uploaded.');
# 		});
# 	  });
# 	}) unless $self->req->is_finished;

# 	# Second invocation, render response
# 	$self->render(text => 'Upload was successful.');
# };

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html ng-app>
	<head>
		<title>Streaming multipart upload</title>
		<script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.0.6/angular.min.js"></script>
		<!-- <script src="gridfs.js"></script>
			<script src="files.js"></script>
		 -->
	</head>
	<body>

		%= form_for upload => (enctype => 'multipart/form-data') => begin
			<input name="example" type="file" multiple />
			%= submit_button 'Upload'
		% end
		<!--<div ng-controller="FilesCtrl">
			<table>
				<thead>
				  	<tr>
						<th>File</th>
						<th>Size</th>
				  	</tr>
				</thead>
				<tbody>
				  	<tr ng-repeat="file in files | filter:search | orderBy:'name'">
						<td><a href="{{file.name}}" target="_blank">{{file.id}}</a></td>
						<td>{{file.size}}</td>
				  	</tr>
				</tbody>
			</table>
		</div> -->
	</body>
</html>

@@ files.js
# angular.module('project', ['mongolab']).
#   config(function($routeProvider) {
#     $routeProvider.
#       when('/', {controller:ListCtrl, templateUrl:'list.html'}).
#       when('/edit/:projectId', {controller:EditCtrl, templateUrl:'detail.html'}).
#       when('/new', {controller:CreateCtrl, templateUrl:'detail.html'}).
#       otherwise({redirectTo:'/'});
#   });
 
function ListCtrl($scope, Files) {
  $scope.files = Files.list();
}
 
 
/* 
function CreateCtrl($scope, $location, Project) {
  $scope.save = function() {
    Project.save($scope.project, function(project) {
      $location.path('/edit/' + project._id.$oid);
    });
  }
}
 
function EditCtrl($scope, $location, $routeParams, Project) {
  var self = this;
 
  Project.get({id: $routeParams.projectId}, function(project) {
    self.original = project;
    $scope.project = new Project(self.original);
  });
 
  $scope.isClean = function() {
    return angular.equals(self.original, $scope.project);
  }
 
  $scope.destroy = function() {
    self.original.destroy(function() {
      $location.path('/list');
    });
  };
 
  $scope.save = function() {
    $scope.project.update(function() {
      $location.path('/');
    });
  };
}
*/

@@ gridfs.js
// Модуль для gridfs api
angular.module('gridfs', ['ngResource']).
	factory('Files', function($resource) {
	  var Files = $resource('http://localhost:3000/gridfs/files',{
			upload: { method: 'POST'},
			download: { method: 'GET', url:'/:objectId' },
			reload: { method: 'PUT', url:'/:objectId' },
			remove: { method: 'DELETE', url:'/:objectId'},
			list: {method: 'GET'}
		}
	);
 
	Files.prototype.update = function(cb) {
		return Files.update({id: this._id.$oid},
			angular.extend({}, this, {_id:undefined}), cb);
	};

	Files.prototype.destroy = function(cb) {
		return Files.remove({id: this._id.$oid}, cb);
	};
 
	return Files;
});

