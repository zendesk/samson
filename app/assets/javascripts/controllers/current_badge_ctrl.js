samson.controller('CurrentBadgeCtrl', ['$log', '$scope', '$http', 'Radar', function($log, $scope, $http, Radar) {
  $log.info('Started the footer controller');

  $scope.count = 0;

  $scope.getActiveCount = function() {
    $log.info('Refreshing active count');
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

  $scope.$on('DeployStarted', function(event, args) {
    $log.info('Deploy Started: ' + JSON.stringify(args));
    $scope.getActiveCount();
  });

  $scope.$on('DeployFinished', function(event, args) {
    $log.info('Deploy Finished: ' + JSON.stringify(args));
    $scope.getActiveCount();
  });

  $log.info('Registered Controller listeners.');
  $scope.getActiveCount();
}]);