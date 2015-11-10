samson.controller('KubernetesCreateRoleCtrl', function($scope, $state, $stateParams, kubernetesService, kubernetesRoleFactory, notificationService, $timeout) {

  $scope.submit = function(e) {
    e.preventDefault(); //prevents default form submission

    kubernetesService.createRole($stateParams.project_id, $scope.role).then(
      function() {
        // Postpones execution of this instruction until the current digest cycle is finished.
        // This was needed to keep the flash message on the page, otherwise it would disappear
        // instantly due to the URL state change that follows.
        $timeout(function() {
          notificationService.success('Role ' + $scope.role.name + ' has been created successfully.');
        });

        $state.go('kubernetes.roles');
      }
    );
  };

  $scope.cancel = function() {
    $state.go('kubernetes.roles');
  };

  function loadRoleDefaults() {
    kubernetesService.loadRoleDefaults($stateParams.project_id).then(function(data) {
        $scope.role = kubernetesRoleFactory.build(data);
      }
    );
  }

  loadRoleDefaults();
});
