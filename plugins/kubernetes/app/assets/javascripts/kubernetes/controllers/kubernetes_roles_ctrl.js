samson.controller('KubernetesRolesCtrl', function($scope, $stateParams, kubernetesService, kubernetesRoleFactory) {
  $scope.project_id = $stateParams.project_id;

  $scope.roles = [];

  function loadRoles() {
    kubernetesService.loadRoles($scope.project_id).then(function(data) {
        $scope.roles = data.map(function(item) {
          return kubernetesRoleFactory.build(item);
        });
      }
    );
  }

  loadRoles();
});


