samson.controller('KubernetesTabsCtrl', function($rootScope, $scope, $window) {
  $scope.tabs = [
    {
      index: 0,
      title: 'Roles',
      state: 'kubernetes.roles'
    },
    {
      index: 1,
      title: 'Tasks',
      state: 'kubernetes.tasks'
    },
    {
      index: 2,
      title: 'Releases',
      state: 'kubernetes.releases'
    },
    {
      index: 3,
      title: 'Dashboard',
      state: 'kubernetes.dashboard'
    }
  ];

  $rootScope.$on('$stateChangeSuccess', function(event, toState, toParams) {
    if(toState.name === 'kubernetes.roles') {
      $window.location.href = '/projects/' + toParams.project_id + '/kubernetes/roles';
    } else if (toState.name === 'kubernetes.tasks') {
      $window.location.href = '/projects/' + toParams.project_id + '/kubernetes/tasks';
    } else {
      $scope.project_id = toParams.project_id;
      _.findWhere($scope.tabs, {index: toState.data.selectedTab}).active = true;
    }
  });
});
