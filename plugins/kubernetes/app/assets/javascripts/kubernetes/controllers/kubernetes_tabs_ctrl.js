samson.controller('KubernetesTabsCtrl', function($rootScope, $scope) {

  $scope.tabs = [
    {
      index: 0,
      title: 'Roles',
      state: 'kubernetes.roles'
    },
    {
      index: 1,
      title: 'Releases',
      state: 'kubernetes.releases'
    },
    {
      index: 2,
      title: 'Dashboard',
      state: 'kubernetes.dashboard'
    }
  ];

  $rootScope.$on('$stateChangeSuccess', function(event, toState, toParams) {
    $scope.project_id = toParams.project_id;
    _.findWhere($scope.tabs, {index: toState.data.selectedTab}).active = true;
  });
});
