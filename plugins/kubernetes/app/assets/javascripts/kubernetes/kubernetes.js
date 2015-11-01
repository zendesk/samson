angular.module('samson').config(function($stateProvider, $urlRouterProvider) {

  $urlRouterProvider.when('/projects/:project_id/kubernetes', '/projects/:project_id/kubernetes/releases');

  $stateProvider
    .state('kubernetes', {
      url: '/projects/:project_id/kubernetes',
      template: '<ui-view/>',
      abstract: true
    })
    .state('kubernetes.roles', {
      url: "/roles",
      data: {
        'selectedTab': 0
      },
      views: {
        'roles@': {
          templateUrl: 'kubernetes/kubernetes_roles.tmpl.html',
          controller: 'KubernetesRolesCtrl'
        }
      }
    })
    .state('kubernetes.releases', {
      url: '/releases',
      data: {
        'selectedTab': 1
      },
      views: {
        'releases@': {
          templateUrl: 'kubernetes/kubernetes_release_groups.tmpl.html',
          controller: 'KubernetesReleaseGroupsCtrl'
        }
      }
    });
});
