samson.controller('KubernetesTabsCtrl', function($rootScope, $scope) {

  $rootScope.$on('$stateChangeSuccess', function(event, newState) {
    $scope.currentTab = newState.data.selectedTab;
  });

});
