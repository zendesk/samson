samson.controller('ProjectRolesCtrl', function($rootScope, $scope, $element, $filter, projectRoleFactory, projectRolesService, messageCenterService) {
  $scope.roles = [];

  (function init() {
    projectRolesService.loadProjectRoles().then(function(data) {
        $scope.roles = data.map(function(item) {
          return projectRoleFactory.buildFromJson(item);
        });
      }
    );
  })();

  $scope.roleChanged = function(project_role) {
    if (project_role.exists()) {
      return updateProjectRole(project_role);
    }
    else {
      return createProjectRole(project_role);
    }
  };

  function createProjectRole(project_role) {
    projectRolesService.createProjectRole(project_role).then(
      function() {
        //Success
        showSuccessMessage(project_role);
      },
      function() {
        //Failure
        showErrorMessage(project_role);
      }
    );
  }

  function updateProjectRole(project_role) {
    projectRolesService.updateProjectRole(project_role).then(
      function() {
        //Success
        showSuccessMessage(project_role);
      },
      function() {
        //Failure
        showErrorMessage(project_role);
      }
    );
  }

  function roleNameFor(role_id) {
    var role = _.findWhere($scope.roles, {id: role_id});
    return _.isUndefined(role) ? '' : role.display_name;
  }

  function showSuccessMessage(project_role) {
    showMessage('success', 'User ' + project_role.user_name + ' has been granted the role ' + roleNameFor(project_role.role_id) + ' for project ' + project_role.project_name);
  }

  function showErrorMessage(project_role) {
    showMessage('danger', "Failed to assign role '" + roleNameFor(project_role.role_id) + "' to User " + project_role.user_name + " on project " + project_role.project_name);
  }

  function showMessage(message_type, message) {
    messageCenterService.markShown();
    messageCenterService.removeShown();
    messageCenterService.add(message_type, message);
  }
});
