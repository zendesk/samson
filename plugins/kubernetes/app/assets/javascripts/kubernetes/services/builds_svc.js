samson.service('buildsService', function($http, $q, buildFactory, httpErrorService) {
  var config = {
    headers: {
      'Accept': 'application/json'
    }
  };

  this.loadBuilds = function(project_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/builds', config).then(
      function(response) {
        deferred.resolve(response.data.builds.map(buildFactory.build));
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };
});
