samson.controller('KubernetesDashboardCtrl',
  function($rootScope, $scope, $stateParams, $q, environmentsService, kubernetesService, SseFactory, notificationService) {
    $scope.project_id = $stateParams.project_id;
    $scope.environments = [];
    $scope.messages = [];
    $scope.dashboard_data = [];
    $scope.environment = undefined;
    $scope.loadingEnvironments = false;
    $scope.loadingClusterState = false;

    $scope.reloadDashboardData = function() {
      loadClusterState();
    };

    $scope.environmentChanged = function(env) {
      $scope.environment = env;
      loadClusterState();
    };

    $scope.dashboardReady = function() {
      return !$scope.loadingEnvironments && !$scope.loadingClusterState;
    };

    $scope.empty = function(collection) {
      return _.isUndefinedOrEmpty(collection);
    };

    $scope.notEmpty = function(collection) {
      return _.isNotUndefinedOrEmpty(collection);
    };

    function init() {
      // Chaining the several promises (they should be resolved sequentially)
      loadEnvironments()
        .then(function() {
            return loadClusterState();
          }
        )
        .then(function() {
            startListeningForUpdates()
          }
        );
    }

    init();

    /*
     Controller private functions.
     */

    function loadEnvironments() {
      $scope.loadingEnvironments = true;

      var deferred = $q.defer();
      environmentsService.loadEnvironments($scope.project_id).then(
        function(environments) {
          $scope.loadingEnvironments = false;
          $scope.environments = environments;

          // Selects the production environment by default
          var default_environment = _.findWhere(environments, {'is_production': true});
          $scope.environment = _.isDefined(default_environment) ? default_environment : environments[0];

          deferred.resolve();
        },
        function(result) {
          $scope.loadingEnvironments = false;
          result.messages.map(function(message) {
            notificationService.error(message);
          });
          deferred.reject();
        }
      );

      return deferred.promise;
    }

    function loadClusterState() {
      $scope.loadingClusterState = true;
      $scope.dashboard_data = [];

      var deferred = $q.defer();
      kubernetesService.loadDashboardData($scope.project_id, $scope.environment).then(
        function(data) {
          $scope.loadingClusterState = false;
          if (_.isNotUndefinedOrEmpty(data)) {
            $scope.dashboard_data = data;
            deferred.resolve();
          }
          else {
            deferred.reject();
          }
        },
        function(result) {
          $scope.loadingClusterState = false;
          result.messages.map(function(message) {
            notificationService.error(message);
          });
          deferred.reject();
        }
      );

      return deferred.promise;
    }

    function startListeningForUpdates() {
      SseFactory.on('k8s', function(msg) {
        var role = findOrCreateRole(msg);
        var deploy_group = findOrCreateDeployGroup(role, msg);
        var release = findOrCreateRelease(deploy_group, msg);
        updateReleaseState(release, msg);
      });
    }

    function findOrCreateRole(msg) {
      var role = findRole(msg.role);

      if (_.isUndefined(role)) {
        role = {
          name: msg.role,
          deploy_groups: []
        };
        $scope.dashboard_data.push(role);
      }

      return role;
    }

    function findOrCreateDeployGroup(role, msg) {
      if (_.isDefined(role)) {
        var deploy_group = findDeployGroup(role, msg.deploy_group);

        if (_.isUndefined(deploy_group)) {
          deploy_group = {
            name: msg.deploy_group,
            releases: []
          };
          role.deploy_groups.push(deploy_group);
        }

        return deploy_group;
      }
    }

    function findOrCreateRelease(deploy_group, msg) {
      if (_.isDefined(deploy_group)) {
        var release = findRelease(deploy_group, msg.release);

        if (_.isUndefined(release)) {
          release = {
            id: msg.release,
            build: msg.build,
            live_replicas: msg.live_replicas,
            target_replicas: msg.target_replicas
          };
          deploy_group.releases.push(release);
        }
        return release;
      }
    }

    function updateReleaseState(release, msg) {
      release.live_replicas = msg.live_replicas;
      $scope.$apply();
    }

    function findRole(role_id) {
      return _.find($scope.dashboard_data, function(role) {
        return role.name == role_id;
      });
    }

    function findDeployGroup(role, deploy_group_name) {
      return _.find(role.deploy_groups, function(deploy_group) {
        return deploy_group.name == deploy_group_name;
      });
    }

    function findRelease(deploy_group, release_id) {
      return _.find(deploy_group.releases, function(release) {
        return release.id == release_id;
      });
    }
  });
