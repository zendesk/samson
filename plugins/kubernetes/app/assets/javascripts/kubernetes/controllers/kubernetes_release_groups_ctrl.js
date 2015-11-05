samson.controller('KubernetesReleaseGroupsCtrl', function($scope, $stateParams, kubernetesService, kubernetesReleaseGroupFactory) {
  $scope.project_id = $stateParams.project_id;

  function loadKubernetesReleaseGroups() {
    kubernetesService.loadKubernetesReleaseGroups($scope.project_id).then(function(data) {
        $scope.release_groups = data.map(function(item) {
          return kubernetesReleaseGroupFactory.build(item);
        });
      }
    );
  }

  loadKubernetesReleaseGroups();

});
