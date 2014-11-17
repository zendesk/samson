samson.controller('CurrentBadgeCtrl', ['$log', '$scope', '$http', 'Radar', function($log, $scope, $http, Radar) {
  $scope.count = 0;

  $scope.getActiveCount = function() {
    $http.get('/deploys/active_count.json').
      success(function(data) {
        if (data != undefined && !isNaN(data.count)) {
          $scope.count = data.count;
        }
      }).
      error(function() {
        $scope.count = '?';
      });
  }

  $scope.$on('DeployCreated', function(event, args) {
    $scope.getActiveCount();
  });

  $scope.$on('DeployStarted', function(event, args) {
    $scope.getActiveCount();
  });

  $scope.$on('DeployFinished', function(event, args) {
    $scope.getActiveCount();
  });

  $scope.getActiveCount();
}]);