samson.directive('projectRoles', function(userProjectRoleFactory) {
  return {
    restrict: 'E',
    templateUrl: 'shared/_project_roles.tmpl.html',
    scope: {
      roles: '=',
      roleChanged: '&'
    },
    link: function($scope, element) {
      $scope.project_role = userProjectRoleFactory.build(element[0]);
    }
  };
});
