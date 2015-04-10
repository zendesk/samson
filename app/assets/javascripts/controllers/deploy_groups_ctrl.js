samson.controller('DeployGroupsCtrl', function($scope, $http, $location, $window) {
  var MAX_PAGES = 20;

  function init() {
    getMoreDeploys(1);
  }

  function getMoreDeploys(page) {
    if (page <= MAX_PAGES) {
      $http.get($location.path() + '.json?page=' + page).success(function(result) {
        if (result.deploys.length > 0) {
          result.deploys.forEach(function(deploy) {
            deploy.start = new Date(deploy.started_at || deploy.created_at);
          });

          $scope.items.add(result.deploys);
          $scope.deployIds = $scope.deployIds.concat(_.pluck(result.deploys, 'id'));

          adjustVisibleItems(result.deploys);
          getMoreDeploys(page + 1);
        }
      });
    }
  }

  function adjustVisibleItems() {
    var visibleItems = $scope.timeline.getVisibleItems().length,
        MIN_VIS_ITEMS = 10,
        MAX_VIS_ITEMS = 20;

    if (visibleItems > MAX_VIS_ITEMS) {
      $scope.timeline.setOptions({
        start: $scope.items.get($scope.deployIds[MAX_VIS_ITEMS-1]).start
      });
    } else if (visibleItems <= MIN_VIS_ITEMS && $scope.items.length > MIN_VIS_ITEMS) {
      $scope.timeline.setOptions({
        start: $scope.items.get($scope.deployIds[MIN_VIS_ITEMS-1]).start
      });
    }
  }

  $scope.items = new vis.DataSet([]);
  $scope.deployIds = [];

  $scope.onDoubleClickItem = function(properties) {
    $window.location.href = $scope.items.get(properties.item).url;
  };

  init();
});
