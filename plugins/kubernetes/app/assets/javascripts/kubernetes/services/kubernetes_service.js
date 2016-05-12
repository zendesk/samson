samson.service('kubernetesService', function($http, $q, httpErrorService, kubernetesRoleFactory, kubernetesReleaseFactory) {

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

    $http.get('/projects/' + project_id + '/kubernetes/roles', config).then(
      function(response) {
        deferred.resolve(response.data.map(kubernetesRoleFactory.build));
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
        deferred.resolve(response.data.map(kubernetesRoleFactory.build));
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
        deferred.resolve(response.data.map(kubernetesReleaseFactory.build));
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };

  this.createRelease = function(project_id, build_id, deploy_groups) {
    var payload = {
      build_id: build_id,
      deploy_groups: deploy_groups.map(deployGroupMapper)
    };

    var deferred = $q.defer();
    $http.post('/projects/' + project_id + '/kubernetes_releases', payload).then(
      function(response) {
        deferred.resolve(response.data);
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );
    return deferred.promise;
  };

  function deployGroupMapper(deploy_group) {
    return {
      id: deploy_group.id,
      roles: deploy_group.roles.map(roleMapper)
    };
  }

  function roleMapper(role) {
    return _.pick(role, 'id', 'replicas');
  }


  this.loadDashboardData = function(project_id, environment) {
    var deferred = $q.defer();

    $http.get('/projects/' + project_id + '/kubernetes_dashboard?environment=' + environment.id, config).then(
      function(response) {
        deferred.resolve(response.data);
      },
      function(response) {
        deferred.reject(httpErrorService.handleResponse(response));
      }
    );

    return deferred.promise;
  };
});
