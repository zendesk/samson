samson.controller('KubernetesCreateReleaseCtrl',
  function($scope, $window, $state, $stateParams, $q, $timeout, $uibModalInstance, buildsService, environmentsService,
           kubernetesService, notificationService) {

    $scope.loadingBuilds = false;
    $scope.loadingRoles = false;
    $scope.loadingEnvironments = false;
    $scope.loadingDeployGroups = false;
    $scope.submitting = false;
    $scope.roles = [];
    $scope.environments = [];
    $scope.environment = undefined;
    $scope.build = undefined;
    $scope.deploy_groups = [];

    loadBuilds();

    loadEnvironments();

    /*
     Scope functions
     */

    $scope.empty = function(collection) {
      return _.isUndefinedOrEmpty(collection);
    };

    $scope.notEmpty = function(collection) {
      return _.isNotUndefinedOrEmpty(collection);
    };

    $scope.wizardReady = function() {
      return _.isNotUndefinedOrEmpty($scope.builds) && _.isNotUndefinedOrEmpty($scope.environments);
    };

    $scope.showProjectBuilds = function() {
      $uibModalInstance.dismiss();
      $window.location.href = '/projects/' + $stateParams.project_id + '/builds/new';
    };

    $scope.showKubernetesRoles = function() {
      $uibModalInstance.dismiss();
      $state.go('kubernetes.roles');
    };

    $scope.cancel = function() {
      $uibModalInstance.dismiss();
      $state.go('kubernetes.releases');
    };

    $scope.buildChanged = function(build) {
      $scope.build = build;
    };

    $scope.environmentChanged = function(environment) {
      $scope.environment = environment;

      if (_.isUndefined($scope.environment)) {
        $scope.roles = [];
        $scope.deploy_groups = [];
      }
      else {
        // Select only the deploy groups associated with a kubernetes cluster
        $scope.deploy_groups = _.filter($scope.environment.deploy_groups, function(deploy_group) {
          return _.isNotUndefinedOrEmpty(deploy_group.kubernetes_cluster);
        });

        loadRoles().then(
          function(roles) {
            _.each($scope.deploy_groups, function(deploy_group) {
              deploy_group.roles = _.cloneArray(roles);
            });
          }
        );
      }
    };

    $scope.toggleAll = function() {
      if(!$scope.submitting) {
        var newState = !$scope.allToggled();
        _.each($scope.deploy_groups, function(deploy_group) {
          deploy_group.selected = newState;
        });
      }
    };

    $scope.allToggled = function() {
      return _.every($scope.deploy_groups, function(deploy_group) {
        return deploy_group.selected;
      });
    };

    $scope.toggleSelection = function(deploy_group) {
      if(!$scope.submitting) {
        deploy_group.selected = !deploy_group.selected;
      }
    };

    $scope.isSelected = function(deploy_group) {
      return deploy_group.selected;
    };

    $scope.validate = function(step) {
      // Returns true if all the conditions are valid
      return _.every([
        _.isDefined($scope.environment),
        _.isDefined($scope.build),
        _.isNotUndefinedOrEmpty($scope.roles),
        step == 1 || _.some($scope.deploy_groups, $scope.isSelected)
      ]);
    };

    $scope.submit = function() {
      createRelease();
    };

    /*
     Controller private functions.
     */

    function loadEnvironments() {
      $scope.loadingEnvironments = true;
      environmentsService.loadEnvironments($stateParams.project_id).then(
        function(environments) {
          $scope.environments = environments;
          $scope.loadingEnvironments = false;
        },
        function(result) {
          handleFailure(result);
        }
      );
    }

    function loadBuilds() {
      $scope.loadingBuilds = true;
      buildsService.loadBuilds($stateParams.project_id).then(
        function(builds) {
          $scope.builds = builds;
          $scope.loadingBuilds = false;
        },
        function(result) {
          handleFailure(result);
        }
      );
    }

    function loadRoles() {
      $scope.roles = [];
      $scope.loadingRoles = true;

      var deferred = $q.defer();
      kubernetesService.loadRoles($stateParams.project_id).then(
        function(roles) {
          $scope.loadingRoles = false;
          $scope.roles = roles;

          //todo: merge with environment defaults

          deferred.resolve(roles);
        },
        function(result) {
          deferred.reject();
          handleFailure(result);
        }
      );
      return deferred.promise;
    }

    function createRelease() {
      $scope.submitting = true;

      // Fetching only the selected deploy groups
      var selected_deploy_groups = _.filter($scope.deploy_groups, $scope.isSelected);

      kubernetesService.createRelease($stateParams.project_id, $scope.build.id, selected_deploy_groups).then(
        function() {
          $uibModalInstance.close();

          // Postpones execution of this instruction until the current digest cycle is finished.
          // This was needed to keep the flash message on the page, otherwise it would disappear
          // instantly due to the URL state change that follows.
          $timeout(function() {
            notificationService.success('The new release has been created successfully and the corresponding deployment is in progress.');
          });
        },
        function(result) {
          $scope.submitting = false;
          handleFailure(result);
        }
      );
    }

    function handleFailure(result) {
      if (result.type == 'error') {
        result.messages.map(function(message) {
          notificationService.error(message);
        });
      }
      else if (result.type == 'warning') {
        result.messages.map(function(message) {
          notificationService.warning(message);
        });
      }
    }
  });
