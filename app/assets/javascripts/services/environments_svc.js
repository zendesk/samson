samson.service('environmentsService', function($http, $q, httpErrorService) {
  var config = {
    headers: {
      'Accept': 'application/json'
    }
  };

  this.loadEnvironments = function() {
    var deferred = $q.defer();

    $http.get('/admin/environments', config).then(
      function(response) {
        deferred.resolve(response.data.environments);
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };
});
