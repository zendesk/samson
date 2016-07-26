samson.controller('currentDeployBadgeCtrl', function($scope, $http, SseFactory) {
  'use strict';

  var $badge = $('#currentDeploysBadge');
  $scope.currentActiveDeploys = parseInt($badge.data('count'), 10);

  // once a user has the page open for a while:
  // - get current active count to reduce race condition
  // - connect to stream for updates
  setTimeout(function(){
    $http.get('/api/deploys/active_count.json').success(function(result) {
      $scope.currentActiveDeploys = result.deploy_count;
      updateBadge();

      SseFactory.on('deploys', function(msg) {
        if (msg.type === 'new') {
          $scope.currentActiveDeploys += 1;
        } else if (msg.type === 'finish') {
          $scope.currentActiveDeploys -= 1;
        }
        updateBadge();
      });
    });
  }, 5000);

  function updateBadge() {
    _.defer(function() { $scope.$apply(); });
    if ($scope.currentActiveDeploys > 0) {
      $badge.show();
    } else {
      $scope.currentActiveDeploys = 0;
      $badge.hide();
    }
  }

  updateBadge();
});
