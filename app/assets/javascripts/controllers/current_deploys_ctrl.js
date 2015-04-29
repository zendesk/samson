samson.controller("currentDeploysCtrl", function($scope, $http, SseFactory, $interval, DeployHelper) {
  'use strict';

  $scope.deploys = [];
  $scope.helper = DeployHelper;

  function updateUpdatedAt() {
    _.each($scope.deploys, function(deploy) {
      deploy.updated_at_ago = moment(deploy.updated_at).fromNow();
    });
  }

  function init() {
    $http.get('/deploys/active.json').success(function(result) {
      $scope.deploys = result.deploys;
      updateUpdatedAt();
    });
  }

  $scope.addDeploy = function(deploy) {
    $scope.deploys = [deploy].concat($scope.deploys);
  };

  $scope.updateDeploy = function(deploy) {
    var index = _.findIndex($scope.deploys, function(d) { return d.id === deploy.id; });
    if (index >= 0) {
      $scope.deploys[index] = deploy;
    }
  };

  $scope.removeDeploy = function(deploy) {
    $scope.deploys = $scope.deploys.filter(function(d) {
      return d.id !== deploy.id;
    });
  };

  SseFactory.on('deploys', function(msg) {
    if (msg.type === 'finish') {
      $scope.removeDeploy(msg.deploy);
    } else if (msg.type === 'new') {
      $scope.addDeploy(msg.deploy);
    } else {
      $scope.updateDeploy(msg.deploy);
    }
    updateUpdatedAt();
    _.defer(function() { $scope.$apply(); });
  });

  $interval(updateUpdatedAt, 10000);

  init();
});
