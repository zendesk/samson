'use strict';

describe("Controller: KubernetesRolesCtrl", function() {
  var $rootScope, $scope, $state, $stateParams, $location, controller, kubernetesService, notificationService;
  var roles = [
    {
      id: 0,
      project_id: 1,
      name: 'some_role_name',
      config_file: 'some_config_file',
      replicas: 1,
      cpu: 0.2,
      ram: 512,
      service_name: 'some_service_name',
      deploy_strategy: 'some_deploy_strategy'
    }
  ];

  function goTo(url) {
    $location.url(url);
    $rootScope.$digest();
  }

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_$rootScope_, _$state_, _$stateParams_, _$location_, $templateCache, _kubernetesService_, _notificationService_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $state = _$state_;
    $stateParams = _$stateParams_;
    $location = _$location_;
    kubernetesService = _kubernetesService_;
    notificationService = _notificationService_;

    $templateCache.put('kubernetes/kubernetes_roles.tmpl.html', '');

    // Setting up the current state and stateParams
    goTo('/projects/some_project/kubernetes/roles');
  }));

  describe('loadRoles', function() {
    beforeEach(inject(function($controller, $q) {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);

      controller = $controller('KubernetesRolesCtrl', {
        $scope: $scope,
        $stateParams: $stateParams,
        kubernetesService: kubernetesService
      });
    }));

    it('should load the roles into the scope', inject(function($q) {
      $scope.$digest();

      expect(kubernetesService.loadRoles).toHaveBeenCalled();
      expect($scope.roles[0].id).toBe(0);
      expect($scope.roles[0].project_id).toBe(1);
      expect($scope.roles[0].name).toBe('some_role_name');
      expect($scope.roles[0].config_file).toBe('some_config_file');
      expect($scope.roles[0].replicas).toBe(1);
      expect($scope.roles[0].cpu).toBe(0.2);
      expect($scope.roles[0].ram).toBe(512);
      expect($scope.roles[0].service_name).toBe('some_service_name');
      expect($scope.roles[0].deploy_strategy).toBe('some_deploy_strategy');
    }));
  });

  describe('loadRoles', function() {
    beforeEach(inject(function($controller, $q) {
      var deferred = $q.defer();
      deferred.reject({type: 'error', messages: ['Some technical error']});
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);

      controller = $controller('KubernetesRolesCtrl', {
        $scope: $scope,
        $stateParams: $stateParams,
        kubernetesService: kubernetesService
      });
    }));

    it('flashes an error message for each error', inject(function($q) {
      spyOn(notificationService, 'error');

      $scope.$digest();

      expect(kubernetesService.loadRoles).toHaveBeenCalled();
      expect(notificationService.error).toHaveBeenCalledWith('Some technical error');

      // Roles have not been initialised
      expect($scope.roles).toBe(undefined);
    }));
  });

  describe("$scope.refreshRoles", function() {

    beforeEach(inject(function($controller, $q) {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);

      controller = $controller('KubernetesRolesCtrl', {
        $scope: $scope,
        $stateParams: $stateParams,
        kubernetesService: kubernetesService
      });
    }));

    it('refreshes the roles on a successful response', inject(function($q, kubernetesService, notificationService) {
      var new_roles = [
        {
          id: 1,
          project_id: 1,
          name: 'another_role_name',
          config_file: 'another_config_file',
          replicas: 2,
          cpu: 0.5,
          ram: 1024,
          service_name: 'another_service_name',
          deploy_strategy: 'another_deploy_strategy'
        }
      ];

      var reference = 'some_reference';

      var deferred = $q.defer();
      deferred.resolve(new_roles);
      spyOn(kubernetesService, 'refreshRoles').and.returnValue(deferred.promise);
      spyOn(notificationService, 'success');
      spyOn($scope, '$broadcast');

      $scope.refreshRoles(reference);
      $scope.$digest();

      expect(kubernetesService.refreshRoles).toHaveBeenCalledWith($stateParams.project_id, reference);
      expect($scope.$broadcast).toHaveBeenCalledWith('gitReferenceSubmissionCompleted');
      expect(notificationService.success).toHaveBeenCalledWith('Kubernetes Roles imported successfully from Git reference: ' + reference);

      // The roles should have been updated
      expect($scope.roles[0].id).toBe(1);
      expect($scope.roles[0].project_id).toBe(1);
      expect($scope.roles[0].name).toBe('another_role_name');
      expect($scope.roles[0].config_file).toBe('another_config_file');
      expect($scope.roles[0].replicas).toBe(2);
      expect($scope.roles[0].cpu).toBe(0.5);
      expect($scope.roles[0].ram).toBe(1024);
      expect($scope.roles[0].service_name).toBe('another_service_name');
      expect($scope.roles[0].deploy_strategy).toBe('another_deploy_strategy');
    }));

    it('flashes a warning message if no roles has been found', inject(function($q, kubernetesService, notificationService) {
      var reference = 'some_reference';

      var deferred = $q.defer();
      deferred.reject({type: 'warning', messages: ['Some message']});
      spyOn(kubernetesService, 'refreshRoles').and.returnValue(deferred.promise);
      spyOn(notificationService, 'warning');
      spyOn($scope, '$broadcast');

      $scope.refreshRoles(reference);
      $scope.$digest();

      expect(kubernetesService.refreshRoles).toHaveBeenCalledWith($stateParams.project_id, reference);
      expect($scope.$broadcast).toHaveBeenCalledWith('gitReferenceSubmissionCompleted');
      expect(notificationService.warning).toHaveBeenCalledWith('Some message');

      // The roles should be intact
      expect($scope.roles[0].id).toBe(0);
      expect($scope.roles[0].project_id).toBe(1);
      expect($scope.roles[0].name).toBe('some_role_name');
      expect($scope.roles[0].config_file).toBe('some_config_file');
      expect($scope.roles[0].replicas).toBe(1);
      expect($scope.roles[0].cpu).toBe(0.2);
      expect($scope.roles[0].ram).toBe(512);
      expect($scope.roles[0].service_name).toBe('some_service_name');
      expect($scope.roles[0].deploy_strategy).toBe('some_deploy_strategy');
    }));

    it('flashes an error message for each error', inject(function($q, kubernetesService, notificationService) {
      var reference = 'some_reference';

      var deferred = $q.defer();
      deferred.reject({type: 'error', messages: ['Some message', 'Another message']});
      spyOn(kubernetesService, 'refreshRoles').and.returnValue(deferred.promise);
      spyOn(notificationService, 'error');
      spyOn($scope, '$broadcast');

      $scope.refreshRoles(reference);
      $scope.$digest();

      expect(kubernetesService.refreshRoles).toHaveBeenCalledWith($stateParams.project_id, reference);
      expect($scope.$broadcast).toHaveBeenCalledWith('gitReferenceSubmissionCompleted');
      expect(notificationService.error).toHaveBeenCalledWith('Some message');
      expect(notificationService.error).toHaveBeenCalledWith('Another message');

      // The roles should be intact
      expect($scope.roles[0].id).toBe(0);
      expect($scope.roles[0].project_id).toBe(1);
      expect($scope.roles[0].name).toBe('some_role_name');
      expect($scope.roles[0].config_file).toBe('some_config_file');
      expect($scope.roles[0].replicas).toBe(1);
      expect($scope.roles[0].cpu).toBe(0.2);
      expect($scope.roles[0].ram).toBe(512);
      expect($scope.roles[0].service_name).toBe('some_service_name');
      expect($scope.roles[0].deploy_strategy).toBe('some_deploy_strategy');
    }));
  });
});
