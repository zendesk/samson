samson.controller('KubernetesReleasesCtrl', function($scope, $state, $stateParams, $uibModal, $timeout, kubernetesService, kubernetesReleaseFactory, notificationService) {
  $scope.project_id = $stateParams.project_id;

  $scope.showCreateReleaseDialog = function() {

    var dialog = $uibModal.open({
      templateUrl: 'kubernetes/kubernetes_release_wizard.tmpl.html',
      controller: 'KubernetesCreateReleaseCtrl',
      size: 'lg'
    });

    dialog.result.then(
      function() {
        $state.go('kubernetes.dashboard');
      },
      function() {
        notificationService.clear();
      }
    );
  };

  function loadKubernetesReleases() {
    kubernetesService.loadKubernetesReleases($scope.project_id).then(
      function(data) {
        $scope.releases = data.map(function(item) {
          return kubernetesReleaseFactory.build(item);
        });
      }
    );
  }

  loadKubernetesReleases();
});
