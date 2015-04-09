samson.controller('currentDeployBadgeCtrl', function($scope, Websocket) {
  Websocket.on('deploys', 'new', function() {
    $scope.currentActiveDeploys += 1;
    updateBadge();
  });

  Websocket.on('deploys', 'finish', function() {
    $scope.currentActiveDeploys -= 1;
    updateBadge();
  });

  function updateBadge() {
    console.log('current count: ', $scope.currentActiveDeploys);
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
