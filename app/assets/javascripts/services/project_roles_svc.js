samson.service('projectRolesService', function($http, $q, CacheFactory) {
  /*
    Creates a cache for project roles to prevent access to the backend each time we need to load the project roles,
    and corresponding delays to show the data in the browser. Only first request will hit the backend.
    Data stored in the browser session storage (when available). If not, it will be stored in memory.
    Cache will expires after 5 minutes (this is a catalog, so, not expect to change that often).
   */
  if (!CacheFactory.get('project_roles_cache')) {
    CacheFactory.createCache('project_roles_cache', {
      deleteOnExpire: 'passive', //expired items deleted on access
      maxAge: 5 * 60 * 1000, //expires after 10 minutes
      storageMode: 'sessionStorage' //stored
    });
  }

  this.loadProjectRoles = function() {
    var deferred = $q.defer();
    $http.get('/project_roles', {cache: CacheFactory.get('project_roles_cache')}).then(
      function(response){
        deferred.resolve(response.data);
      }
    );
    return deferred.promise;
  };

  this.createProjectRole = function(project_role) {
    var payload = JSON.stringify(project_role, ['user_id', 'project_id', 'role_id']);

    var deferred = $q.defer();
    $http.post('/projects/' + project_role.project_id + '/project_roles', payload).then(
      function(response) {
        project_role.id = response.data.id;
        deferred.resolve();
      },
      function() {
        deferred.reject();
      }
    );
    return deferred.promise;
  };

  this.updateProjectRole = function(project_role) {
    var payload = JSON.stringify(project_role, ['role_id']);
    return $http.put('/projects/' + project_role.project_id + '/project_roles/' + project_role.id, payload);
  };
});
