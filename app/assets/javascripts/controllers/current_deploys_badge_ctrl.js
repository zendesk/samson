samson.controller('currentDeployBadgeCtrl', function($scope, Websocket) {
  $scope.currentActiveDeploys = 0;

  Websocket.on('deploys', 'new', function() {
    $scope.currentActiveDeploys += 1;
    updateBadge();
  });

  Websocket.on('deploys', 'finish', function() {
    $scope.currentActiveDeploys -= 1;
    updateBadge();
  });

  function updateBadge() {
    if ($scope.currentActiveDeploys > 0) {
      $('#current_deploys_badge').show();
    }
    else {
      $scope.currentActiveDeploys = 0;
      $('.badge').hide();
    }
  }

  $scope.init = function(value) {
    $scope.currentActiveDeploys = value;
    updateBadge();
  }
});
