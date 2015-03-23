samson.controller("DashboardsCtrl", function DashboardsCtrl($scope, $http, $location) {
  'use strict';

  $scope.projects = [];

  function init() {
    $http.get($location.path() + '/deploy_groups').then(function(result) {
      $scope.deploy_groups = result.data.deploy_groups;
      getProjects();
    });
  }

  function getProjects() {
    var deploy_groups_ids = _.pluck($scope.deploy_groups, 'id');

    $http.get('/projects.json').then(function(projects_result) {
      projects_result.data.projects.forEach(function(project) {
        $scope.projects.push(project);
        $http.get(project.url + '/deploy_group_versions.json', { params: { before: $location.search().before } })
          .then(function (deploys_result) {
            project.deploy_group_versions = _.pick(deploys_result.data, deploy_groups_ids);
            project.css = getProjectCss(project);
          })
      });
    });
  }

  function getProjectCss(project) {
    var css = {},
        num_versions;

    num_versions = _.uniq(_.map(project.deploy_group_versions, function(deploy, _id) {
      return deploy.reference;
    })).length;

    if (num_versions > 1) {
      css.class = "warning";
    } else if (num_versions == 0) {
      css.class = "no-deploys";
      css.style = "display: none;";
    }
    return css;
  }

  init();
});
