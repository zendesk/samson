samson.directive('deployProgressWidget', function() {
  return {
    restrict: 'E',
    templateUrl: 'kubernetes/deploy_progress_widget.tmpl.html',
    scope: {
      role: '=',
      deployGroup: '='
    },
    controller: function($scope) {

      $scope.currentRelease = function(release) {
        var current = $scope.lastRelease();
        return release.id == current.id;
      };

      $scope.progress = function(release) {
        return (($scope.liveReplicas(release) * 100) / $scope.replicasTotal(release)) + '%';
      };

      $scope.deployCompleted = function() {
        return _.every($scope.deployGroup.releases, function(release) {
          return $scope.currentRelease(release) ? $scope.targetStateReached(release) : $scope.liveReplicas(release) == 0;
        });
      };

      $scope.deployFailed = function() {
        // TODO: figure out if this will ever be used
        return false;
      };

      $scope.targetStateReached = function(release) {
        return $scope.liveReplicas(release) == $scope.replicasTotal(release);
      };

      $scope.lastRelease = function() {
        return _.max($scope.deployGroup.releases, function(release) {
          return release.id;
        });
      };

      $scope.pendingReplicas = function(release) {
        return $scope.replicasTotal(release) - $scope.liveReplicas(release);
      };

      $scope.liveReplicas = function(release) {
        return release.live_replicas;
      };

      $scope.replicasTotal = function(release) {
        return release.target_replicas;
      };

      $scope.buildLabel = function(release) {
        return release.build;
      };

      $scope.releaseId = function(release) {
        return release.id;
      };
    }
  }
});
