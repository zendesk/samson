samson.controller("RecentDeploysCtrl",
  function($scope, $timeout, Deploys, DeployHelper, StatusFilterMapping) {
    'use strict';

    $scope.userTypes = ["Human", "Robot"];
    $scope.stageTypes = { "Production": true, "Non-Production": false };
    $scope.deployStatuses = Object.keys(StatusFilterMapping);
    $scope.heading = 'Recent Deploys';

    $scope.enableFilters = true;

    $scope.helpers = DeployHelper;
    $scope.deploys = Deploys;

    $scope.helpers.registerScrollHelpers($scope);
    $scope.deploys.loadMore();

    $timeout(function() {
      $('select').selectpicker();
    });
  });
