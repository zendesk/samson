angular.module('samson').config(function($stateProvider, $urlRouterProvider) {

  $urlRouterProvider.when('/projects/:project_id/kubernetes', '/projects/:project_id/kubernetes/releases');

  $stateProvider
    .state('kubernetes', {
      url: '/projects/:project_id/kubernetes',
      abstract: true
    })

    /*
     Kubernetes Roles
     */
    .state('kubernetes.roles', {
      data: {}
    })

    /*
      Kubernetes Releases
     */
    .state('kubernetes.releases', {
      url: '/releases',
      data: {
        'selectedTab': 1
      },
      views: {
        'content@': {
          templateUrl: 'kubernetes/kubernetes_releases.tmpl.html',
          controller: 'KubernetesReleasesCtrl'
        }
      }
    })

    /*
      Kubernetes Dashboard
     */
    .state('kubernetes.dashboard', {
      url: '/dashboard',
      data: {
        'selectedTab': 2
      },
      views: {
        'content@': {
          templateUrl: 'kubernetes/dashboard.tmpl.html',
          controller: 'KubernetesDashboardCtrl'
        }
      }
    })
  ;
});
