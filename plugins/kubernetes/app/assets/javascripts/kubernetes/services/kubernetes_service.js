samson.service('kubernetesService', function($http, $q, httpErrorService, kubernetesRoleFactory) {

  var config = {
    headers: {
      'Accept': 'application/json'
    }
  };

  /*********************************************************************
   Kubernetes Roles
   *********************************************************************/

  this.loadRoles = function(project_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_roles', config).then(
      function(response) {
        deferred.resolve(response.data.map(function(role) {
          return kubernetesRoleFactory.build(role);
        }));
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };

  this.loadRole = function(project_id, role_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_roles/' + role_id, config).then(
      function(response) {
        deferred.resolve(kubernetesRoleFactory.build(response.data));
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };

  this.updateRole = function(project_id, role) {
    var payload = JSON.stringify(role, _.without(Object.keys(role), 'id', 'project_id'));

    var deferred = $q.defer();
    $http.put('/projects/' + project_id + '/kubernetes_roles/' + role.id, payload).then(
      function() {
        deferred.resolve();
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );
    return deferred.promise;
  };

  this.refreshRoles = function(project_id, reference) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_roles/refresh?ref=' + reference, config).then(
      function(response) {
        deferred.resolve(response.data.map(function(role) {
          return kubernetesRoleFactory.build(role);
        }));
      },
      function(response) {
        switch (response.status) {
          case 404:
            deferred.reject(httpErrorService.createResultType('warning', 'No roles have been found for the given Git reference.'));
            break;
          default:
            deferred.reject(httpErrorService.handleResponse(response));
        }
      }
    );

    return deferred.promise;
  };

  /*********************************************************************
   Kubernetes Releases
   *********************************************************************/

  this.loadKubernetesReleases = function(project_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_releases', config).then(
      function(response) {
        deferred.resolve(response.data);
      },
      function(response) {
        deferred.reject(handleFailure(response));
      }
    );

    return deferred.promise;
  };
});
