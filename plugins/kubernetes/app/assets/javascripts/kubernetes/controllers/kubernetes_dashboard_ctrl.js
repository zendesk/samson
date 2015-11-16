samson.controller('KubernetesDashboardCtrl', function($scope, $stateParams, SseFactory) {
  $scope.project_id = $stateParams.project_id;
  $scope.messages = [];

  function init() {
    // Subscribe to the SSE channel for K8s
    SseFactory.on('k8s', function(msg) {
      console.log("Got SSE msg: ", msg);
      $scope.messages.push(JSON.stringify(msg));
      _.defer(function() { $scope.$apply(); });
    });
  }

  init();
});
