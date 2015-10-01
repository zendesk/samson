samson.controller('ProjectRolesCtrl', function($rootScope, $scope, $element, $filter, userProjectRoleFactory, projectRoleFactory, projectRolesService, messageCenterService) {
  $scope.project_role = {};
  $scope.roles = [];

  $scope.initModel = function() {
    $scope.project_role = userProjectRoleFactory.build($element[0]);
    loadProjectRoles();
  };

  $scope.roleChanged = function() {
    if ($scope.project_role.exists()) {
      return updateProjectRole($scope.project_role);
    }
    else {
      return createProjectRole($scope.project_role);
    }
  };

  function loadProjectRoles() {
    projectRolesService.loadProjectRoles().then(function(response) {
        $scope.roles = response.data.map(function(item) {
          return projectRoleFactory.buildFromJson(item);
        });
      }
    );
  }

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
    return _.isUndefined(role) ? '' :  role.display_name;
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
