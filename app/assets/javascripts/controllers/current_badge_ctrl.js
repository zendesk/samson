samson.controller('CurrentBadgeCtrl', function($log, $scope, $http, Radar) {
  'use strict';

  $scope.count = 0;

  $scope.getActiveCount = function() {
    $http.get('/deploys/active_count.json').
      success(function(data) {
        if (data != undefined && !isNaN(data.count) && data.count > 0) {
          $scope.count = data.count;
          A.$('.badge').removeClass('hidden');
        }
        else {
          $scope.count = 0;
          A.$('.badge').addClass('hidden');
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
});
