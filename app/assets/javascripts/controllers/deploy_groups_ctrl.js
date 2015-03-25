samson.controller('DeployGroupsCtrl', function($scope, $http, $location, $window) {

  function init() {
    $http.get($location.path() + '.json').success(function(result) {
      result.deploys.forEach(function(deploy) {
        if (deploy.started_at != undefined) {
          deploy.start = new Date(deploy.started_at);
        } else {
          deploy.start = new Date(deploy.created_at);
        }
      });
      $scope.items.add(result.deploys);
    });
  }

  $scope.items = new vis.DataSet([]);

  $scope.onDoubleClickItem = function(properties) {
    $window.location.href = $scope.items.get(properties.item).url;
  };

  init();
});
