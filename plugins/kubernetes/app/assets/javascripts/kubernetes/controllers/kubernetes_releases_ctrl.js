samson.controller('KubernetesReleasesCtrl', function($scope, $state, $stateParams, $uibModal, kubernetesService, notificationService) {
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
      function(releases) {
        $scope.releases = releases;
      },
      function(result) {
        result.messages.map(function(message) {
          notificationService.error(message);
        });
      }
    );
  }

  loadKubernetesReleases();
});
