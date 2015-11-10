samson.controller('KubernetesRolesCtrl', function($scope, $stateParams, kubernetesService, notificationService) {
  $scope.project_id = $stateParams.project_id;

  $scope.refreshRoles = function(reference) {
    // Broadcast event to child controllers (i.e., the Git reference typeahead directive)
    $scope.$broadcast('gitReferenceSubmissionStart');

    kubernetesService.refreshRoles($scope.project_id, reference).then(
      function(roles) {
        $scope.roles = roles;
        $scope.$broadcast('gitReferenceSubmissionCompleted');
        notificationService.success('Kubernetes Roles imported successfully from Git reference: ' + reference);
      },
      function(result) {
        $scope.$broadcast('gitReferenceSubmissionCompleted');
        handleFailure(result);
      }
    );
  };

  function loadRoles() {
    kubernetesService.loadRoles($scope.project_id).then(
      function(roles) {
        $scope.roles = roles;
      },
      function(result) {
        handleFailure(result);
      }
    );
  }

  function handleFailure(result) {
    if(result.type == 'error') {
      result.messages.map(function(message) {
        notificationService.error(message);
      });
    }
    else if(result.type == 'warning'){
      result.messages.map(function(message) {
        notificationService.warning(message);
      });
    }
  }

  loadRoles();
});


