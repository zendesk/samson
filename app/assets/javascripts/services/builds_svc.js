samson.service('buildsService', function($http, $q, httpErrorService) {
  var config = {
    headers: {
      'Accept': 'application/json'
    }
  };

  this.loadBuilds = function(project_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/builds', config).then(
      function(response) {
        deferred.resolve(response.data.builds);
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };
});
