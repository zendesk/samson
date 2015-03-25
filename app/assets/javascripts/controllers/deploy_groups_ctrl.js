samson.controller('DeployGroupsCtrl', function($scope, $http, $location) {

  function init() {
    $http.get($location.path() + '/deploys.json').success(function(result) {
      result.deploys.forEach(function(deploy) {
        deploy.content = deploy.reference;
        deploy.start = new Date(deploy.started_at);
        deploy.group = deploy.project.id;
      });
      console.log('Result: ', result.deploys);
      $scope.items.add(result.deploys);
    });
  }

  // Configuration for the Timeline
  $scope.items = new vis.DataSet([]);
  $scope.options = {};

  $scope.onItemSelect = function(properties) {
    var selected = $scope.items.get(properties.items[0]);
    console.log("Selected node: ", selected);
  };

  init();
});
