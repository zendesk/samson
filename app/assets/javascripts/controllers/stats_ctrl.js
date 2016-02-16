samson.controller('StatsCtrl', function($scope, $http, messageCenterService) {
  $scope.getProjectLeaderboard = function () {
    $http.get('/stats/projects.json').then(
      function (response) {
        console.log(response);
      },
      function (response) {
        // todo flash error
        console.log("Error");
      }
    );
  };

  $scope.getProjectLeaderboard();

});
