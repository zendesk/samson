samson.controller("CurrentDeploysCtrl", ["$scope", '$log', "DeployHelper", "Deploys",
  function($scope, $log, DeployHelper, Deploys) {
    $scope.helpers = DeployHelper;
    $scope.helpers.registerScrollHelpers($scope);

    $scope.enableFilters = false;
    $scope.heading = 'Current Deploys';

    $scope.deploys = Deploys;
    $scope.deploys.url = '/deploys/active.json';
    $scope.deploys.loadMore();

    $scope.$on('DeployStarted', function(event, args) {
      $log.info('Deploy change, reloading list: ' + JSON.stringify(args));
      $scope.deploys.reload();
    });

    $scope.$on('DeployFinished', function(event, args) {
      $log.info('Deploy Finished: ' + JSON.stringify(args));
      $scope.deploys.reload();
    });

  }]);
