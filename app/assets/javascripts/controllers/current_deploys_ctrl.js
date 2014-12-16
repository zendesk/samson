samson.controller("CurrentDeploysCtrl", function($scope, $log, DeployHelper, Deploys) {
  'use strict';

  $scope.helpers = DeployHelper;
  $scope.helpers.registerScrollHelpers($scope);

  $scope.enableFilters = false;
  $scope.heading = 'Current Deploys';

  $scope.deploys = Deploys;
  $scope.deploys.url = '/deploys/active.json';
  $scope.deploys.loadMore();

  $scope.$on('DeployCreated', function(event, args) {
    $scope.deploys.reload();
  });

  $scope.$on('DeployStarted', function(event, args) {
    $scope.deploys.reload();
  });

  $scope.$on('DeployFinished', function(event, args) {
    $scope.deploys.reload();
  });

});
