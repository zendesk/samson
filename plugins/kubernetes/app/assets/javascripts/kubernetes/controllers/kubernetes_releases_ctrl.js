samson.controller('KubernetesReleasesCtrl', function($scope, $stateParams, kubernetesService, kubernetesReleaseFactory) {
  $scope.project_id = $stateParams.project_id;

  function loadKubernetesReleases() {
    kubernetesService.loadKubernetesReleases($scope.project_id).then(function(data) {
        $scope.releases = data.map(function(item) {
          return kubernetesReleaseFactory.build(item);
        });
      }
    );
  }

  loadKubernetesReleases();
});
