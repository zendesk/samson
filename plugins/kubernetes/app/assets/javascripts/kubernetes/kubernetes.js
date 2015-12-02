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
      url: "/roles",
      data: {
        'selectedTab': 0
      },
      views: {
        'content@': {
          templateUrl: 'kubernetes/kubernetes_roles.tmpl.html',
          controller: 'KubernetesRolesCtrl'
        }
      }
    })
    .state('kubernetes.roles.edit', {
      url: "/:role_id/edit",
      views: {
        'content@': {
          templateUrl: 'kubernetes/kubernetes_edit_role.tmpl.html',
          controller: 'KubernetesEditRoleCtrl'
        }
      }
    })
    .state('kubernetes.roles.create', {
      url: "/new",
      views: {
        'content@': {
          templateUrl: 'kubernetes/kubernetes_create_role.tmpl.html',
          controller: 'KubernetesCreateRoleCtrl'
        }
      }
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
