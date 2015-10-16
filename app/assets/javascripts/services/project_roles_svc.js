samson.service('projectRolesService', function($http, $q) {
  this.loadProjectRoles = function() {
    return $http.get('/project_roles');
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
