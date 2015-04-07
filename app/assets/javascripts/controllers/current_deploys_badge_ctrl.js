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
      $('#current_deploys_badge').text($scope.currentActiveDeploys);
      $('#current_deploys_badge').removeClass('hidden');
    }
    else {
      $scope.currentActiveDeploys = 0;
      $('.badge').addClass('hidden');
    }
  }

  updateBadge();
});
