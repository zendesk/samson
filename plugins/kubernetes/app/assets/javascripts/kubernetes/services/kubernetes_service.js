samson.service('kubernetesService', function($http, $q) {

  var config = {
    headers: {
      'Accept': 'application/json'
    }
  };

  this.loadRoles = function(project_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_roles', config).then(
      function(response) {
        deferred.resolve(response.data);
      }
    );

    return deferred.promise;
  };

  this.loadRole = function(project_id, role_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_roles/' + role_id, config).then(
      function(response) {
        deferred.resolve(response.data);
      }
    );

    return deferred.promise;
  };

  this.loadRoleDefaults = function(project_id) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_roles/new', config).then(
      function(response) {
        deferred.resolve(response.data);
      }
    );

    return deferred.promise;
  };

  this.updateRole = function(project_id, role) {
    var payload = JSON.stringify(role, _.without(Object.keys(role), 'id', 'project_id'));

    var deferred = $q.defer();
    $http.put('/projects/' + project_id + '/kubernetes_roles/' + role.id, payload).then(
      function(response) {
        deferred.resolve(response.data);
      },
      function(response) {
        handleError(response, deferred);
      }
    );
    return deferred.promise;
  };

  this.createRole = function(project_id, role) {
    var payload = JSON.stringify(role, _.without(Object.keys(role), 'id', 'project_id'));

    var deferred = $q.defer();
    $http.post('/projects/' + project_id + '/kubernetes_roles', payload).then(
      function(response) {
        deferred.resolve(response.data);
      },
      function(response) {
        handleError(response, deferred);
      }
    );
    return deferred.promise;
  };

  function handleError(response, deferred) {
    if (!_.isUndefined(response.data) && !_.isUndefined(response.data.errors)) {
      deferred.reject(response.data.errors.map(function(error) {
        return error.message;
      }));
    }
    else {
      deferred.reject();
    }
  }

});
