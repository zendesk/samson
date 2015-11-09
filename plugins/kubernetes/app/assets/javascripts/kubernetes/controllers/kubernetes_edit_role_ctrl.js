samson.controller('KubernetesEditRoleCtrl', function($scope, $state, $stateParams, kubernetesService, kubernetesRoleFactory, notificationService, $timeout) {

  $scope.submit = function(e) {
    e.preventDefault(); //prevents default form submission

    kubernetesService.updateRole($stateParams.project_id, $scope.role).then(
      function() {
        // Postpones execution of this instruction until the current digest cycle is finished.
        // This was needed to keep the flash message on the page, otherwise it would disappear
        // instantly due to the URL state change that follows.
        $timeout(function() {
          notificationService.success('Role ' + $scope.role.name + ' has been successfully updated.');
        });

        $state.go('kubernetes.roles');
      },
      function(errors) {
        if (_.isUndefined(errors)) {
          notificationService.error('Role could not be updated. Please, try again later.');
        }
        else {
          notificationService.errors(errors);
        }
      }
    );
  };

  $scope.cancel = function() {
    $state.go('kubernetes.roles');
  };

  function loadRole() {
    kubernetesService.loadRole($stateParams.project_id, $stateParams.role_id).then(function(data) {
        $scope.role = kubernetesRoleFactory.build(data);
      }
    );
  }

  loadRole();

});
