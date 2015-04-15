samson.controller("DashboardsCtrl", function DashboardsCtrl($scope, $http, $location) {
  'use strict';

  $scope.projects = [];

  function init() {
    $http.get($location.path() + '/deploy_groups').success(function(result) {
      $scope.deploy_groups = result.deploy_groups;
      getProjects();
    });
  }

  function getProjects() {
    var deploy_groups_ids = _.pluck($scope.deploy_groups, 'id');

    $http.get('/projects.json').success(function(projects_result) {
      projects_result.projects.forEach(function(project) {
        $scope.projects.push(project);
        $http.get(project.url + '/deploy_group_versions.json', { params: { before: $location.search().before } })
          .success(function (deploys_result) {
            project.deploy_group_versions = _.pick(deploys_result, deploy_groups_ids);
            project.css = getProjectCss(project);
          });
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
      css.tr_class = "warning";
    } else if (num_versions === 0) {
      css.tr_class = "no-deploys";
      css.style = "display: none;";
    }
    return css;
  }

  init();
});
