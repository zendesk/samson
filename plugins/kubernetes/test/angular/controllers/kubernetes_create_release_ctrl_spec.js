'use strict';

describe("Controller: KubernetesCreateReleaseCtrl", function() {
  var $rootScope, $scope, $q, $state, $stateParams, $location, $templateCache, $timeout, fakeWindowObj, controller,
    fakeModalInstance, buildsService, environmentsService, kubernetesService, notificationService;

  var roles, environments, builds;

  function setupSpyOnBuildsService() {
    var deferred = $q.defer();
    deferred.resolve(builds);
    spyOn(buildsService, 'loadBuilds').and.returnValue(deferred.promise);
  }

  function setupSpyOnEnvironmentsService() {
    var deferred = $q.defer();
    deferred.resolve(environments);
    spyOn(environmentsService, 'loadEnvironments').and.returnValue(deferred.promise);
  }

  // Load the main application module
  beforeEach(function() {
    module("samson");
  });

  // Reset the test data
  beforeEach(function(){
    environments = [
      {
        name: 'an environment',
        deploy_groups: [
          {name: 'a deploy group'},
          {name: 'another deploy group', kubernetes_cluster: {label: 'a cluster'}}
        ]
      }
    ];

    builds = [
      {
        id: 'a build id',
        label: 'a build'
      }
    ];

    roles = [
      {name: 'a role'},
      {name: 'another role'}
    ];
  });

  // Reset the controller
  beforeEach(inject(function($injector) {
    $rootScope = $injector.get('$rootScope');
    $scope = $rootScope.$new();
    $location = $injector.get('$location');
    $templateCache = $injector.get('$templateCache');
    $state = $injector.get('$state');
    $q = $injector.get('$q');
    $stateParams = $injector.get('$stateParams');
    $timeout = $injector.get('$timeout');
    buildsService = $injector.get('buildsService');
    environmentsService = $injector.get('environmentsService');
    kubernetesService = $injector.get('kubernetesService');
    notificationService = $injector.get('notificationService');

    $templateCache.put('kubernetes/kubernetes_releases.tmpl.html', '');

    // Setting up the current state and stateParams
    $location.url('/projects/some_project/kubernetes/releases');
    $rootScope.$digest();

    // Setting up the mock modal instance
    fakeModalInstance = {
      close: jasmine.createSpy('fakeModalInstance.close'),
      dismiss: jasmine.createSpy('fakeModalInstance.dismiss')
    };

    // Setting up the mock Window object
    fakeWindowObj = {location: {href: ''}};

    // Setting up spies for the services called during controller initialization
    setupSpyOnBuildsService();
    setupSpyOnEnvironmentsService();

    var $controller = $injector.get('$controller');
    controller = $controller('KubernetesCreateReleaseCtrl', {
      $window: fakeWindowObj,
      $scope: $scope,
      $stateParams: $stateParams,
      $uibModalInstance: fakeModalInstance,
      buildsService: buildsService,
      environmentsService: environmentsService,
      kubernetesService: kubernetesService,
      notificationService: notificationService
    });

    // Trigger the digest cycle for the promises that have been set up for the controller initialization
    $scope.$digest();
  }));

  afterEach(function(){
    expect(buildsService.loadBuilds).toHaveBeenCalledWith('some_project');
    expect(environmentsService.loadEnvironments).toHaveBeenCalledWith('some_project');
  });

  describe('on controller initialization', function() {
    it('the builds are loaded into the scope', function() {
      expect($scope.builds).toBeDefined();
      expect($scope.builds).toEqual(builds);
    });

    it('the environments are loaded into the scope', function() {
      expect($scope.environments).toBeDefined();
      expect($scope.environments).toEqual(environments);
    });
  });

  describe('empty', function() {
    it('should return true if the collection is empty or undefined', function() {
      expect($scope.empty(undefined)).toBe(true);
      expect($scope.empty([])).toBe(true);
    });

    it('should return false if the collection is not empty', function() {
      expect($scope.empty(['an_item'])).toBe(false);
    });
  });

  describe('notEmpty', function() {
    it('should return false if the collection is empty or undefined', function() {
      expect($scope.notEmpty(undefined)).toBe(false);
      expect($scope.notEmpty([])).toBe(false);
    });

    it('should return true if the collection is not empty', function() {
      expect($scope.notEmpty(['an_item'])).toBe(true);
    });
  });

  describe('wizardReady', function() {
    it('should return true if builds and environments have been loaded', function() {
      $scope.builds = ['a_build'];
      $scope.environments = ['an_environment'];
      expect($scope.wizardReady()).toBe(true);
    });

    it('should return false if builds have not been loaded yet', function() {
      $scope.builds = [];
      $scope.environments = ['an_environment'];
      expect($scope.wizardReady()).toBe(false);
    });

    it('should return false if builds have not been loaded yet', function() {
      $scope.builds = ['a_build'];
      $scope.environments = [];
      expect($scope.wizardReady()).toBe(false);
    });
  });

  describe('showProjectBuilds', function() {
    it('should redirect the user to the builds page', function() {
      $scope.showProjectBuilds();
      expect(fakeModalInstance.dismiss).toHaveBeenCalled();
      expect(fakeWindowObj.location.href).toBe('/projects/some_project/builds/new');
    });
  });

  describe('showKubernetesRoles', function() {
    it('should redirect the user to the roles page', function() {
      spyOn($state, 'go');

      $scope.showKubernetesRoles();
      expect(fakeModalInstance.dismiss).toHaveBeenCalled();
      expect($state.go).toHaveBeenCalledWith('kubernetes.roles');
    });
  });

  describe('cancel', function() {
    it('should keep the user in the releases page', function() {
      spyOn($state, 'go');

      $scope.cancel();
      expect(fakeModalInstance.dismiss).toHaveBeenCalled();
      expect($state.go).toHaveBeenCalledWith('kubernetes.releases');
    });
  });

  describe('buildChanged', function() {
    it('should update the scope with the given build', function() {
      expect($scope.build).toBeUndefined();
      $scope.buildChanged(builds[0]);
      expect($scope.build).toBe(builds[0]);
    });
  });

  describe('environmentChanged', function() {
    beforeEach(function() {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
    });

    it('should update the scope with the given environment', function() {
      expect($scope.environment).toBeUndefined();
      $scope.environmentChanged(environments[0]);
      expect($scope.environment).toBe(environments[0]);
    });

    it('should update scope.deploy_groups with the deploy_groups associated to a cluster', function() {
      expect($scope.deploy_groups.length).toBe(0);
      $scope.environmentChanged(environments[0]);
      expect($scope.deploy_groups.length).toBe(1);
      expect($scope.deploy_groups[0].name).toBe('another deploy group');
      expect($scope.deploy_groups[0].kubernetes_cluster).toBeDefined();
      expect($scope.deploy_groups[0].selected).toBeUndefined();
    });

    it('should update scope.roles', function() {
      expect($scope.roles.length).toBe(0);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();
      expect(kubernetesService.loadRoles).toHaveBeenCalledWith('some_project');
      expect($scope.roles).toBeDefined();
      expect($scope.roles.length).toBe(2);
      expect($scope.roles[0].name).toBe('a role');
      expect($scope.roles[1].name).toBe('another role');
    });

    it('should clone the roles to each deploy_group', function() {
      $scope.environmentChanged(environments[0]);
      $scope.$digest();
      expect(kubernetesService.loadRoles).toHaveBeenCalledWith('some_project');
      _.each($scope.deploy_groups, function(deploy_group) {
        expect(deploy_group.roles).toBeDefined();
        expect(deploy_group.roles.length).toBe(2);
        expect(deploy_group.roles).not.toBe(roles); //should be a clone, not the same array
        expect(deploy_group.roles).toEqual(roles);
      });
    });
  });

  describe('toggleAll', function() {
    beforeEach(function() {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();
    });

    it('should toggle all the deploy groups', function() {
      // All should be selected
      $scope.toggleAll();
      expect(_.every($scope.deploy_groups, function(deploy_group) {
        return deploy_group.selected;
      })).toBe(true);

      // All should be unselected
      $scope.toggleAll();
      expect(_.every($scope.deploy_groups, function(deploy_group) {
        return !deploy_group.selected;
      })).toBe(true);
    });
  });

  describe('allToggled', function() {
    beforeEach(function() {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();
    });

    it('should return true if all deploy groups have been selected', function() {
      _.each($scope.deploy_groups, function(dg) {
        dg.selected = true;
      });
      expect($scope.allToggled()).toBe(true);
    });

    it('should return false if no deploy group has been selected', function() {
      _.each($scope.deploy_groups, function(dg) {
        dg.selected = false;
      });
      expect($scope.allToggled()).toBe(false);
    });

    it('should return false if there is at least one deploy group not selected', function() {
      _.each($scope.deploy_groups, function(dg) {
        dg.selected = true;
      });
      $scope.deploy_groups[0].selected = false;
      expect($scope.allToggled()).toBe(false);
    });
  });

  describe('toggleSelection', function() {
    beforeEach(function() {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();
    });

    it('should toggle the selection of a deploy group', function() {
      _.each($scope.deploy_groups, function(dg) {
        dg.selected = true;
      });

      $scope.toggleSelection($scope.deploy_groups[0]);
      expect($scope.deploy_groups[0].selected).toBe(false);

      $scope.toggleSelection($scope.deploy_groups[0]);
      expect($scope.deploy_groups[0].selected).toBe(true);
    });
  });

  describe('isSelected', function() {
    beforeEach(function() {
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();
    });

    it('should return true if the deploy group is selected, false otherwise', function() {
      $scope.deploy_groups[0].selected = true;
      expect($scope.isSelected($scope.deploy_groups[0])).toBe(true);

      $scope.deploy_groups[0].selected = false;
      expect($scope.isSelected($scope.deploy_groups[0])).toBe(false);
    });
  });

  describe('validate', function() {
    beforeEach(function(){
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
    });

    it('step #1: should return true if all conditions pass', function() {
      $scope.buildChanged(builds[0]);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();

      // Conditions to pass Step #1: build selected, environment selected and roles.length > 0
      expect($scope.build).toBeDefined();
      expect($scope.environment).toBeDefined();
      expect($scope.roles.length).toBeGreaterThan(0);

      expect($scope.validate(1)).toBe(true);
    });

    it('step #1: should return false if the environment was not selected', function() {
      $scope.buildChanged(builds[0]);
      expect($scope.build).toBeDefined();
      expect($scope.environment).toBeUndefined();
      expect($scope.roles.length).toBe(0);

      expect($scope.validate(1)).toBe(false);
    });

    it('step #1: should return false if the build was not selected', function() {
      $scope.environmentChanged(environments[0]);
      $scope.$digest();

      expect($scope.build).toBeUndefined();
      expect($scope.environment).toBeDefined();
      expect($scope.roles.length).toBeGreaterThan(0);

      expect($scope.validate(1)).toBe(false);
    });

    it('step #2: should return true if all conditions pass', function() {
      $scope.buildChanged(builds[0]);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();

      $scope.toggleSelection($scope.deploy_groups[0]);

      // Conditions to pass Step #2: build selected, environment selected, roles.length > 0
      // and at least a deploy group selected
      expect($scope.build).toBeDefined();
      expect($scope.environment).toBeDefined();
      expect($scope.roles.length).toBeGreaterThan(0);
      expect(_.some($scope.deploy_groups, $scope.isSelected)).toBe(true);

      expect($scope.validate(2)).toBe(true);
    });

    it('step #2: should return false if no deploy group has been selected', function() {
      $scope.buildChanged(builds[0]);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();

      // Conditions to pass Step #2: build selected, environment selected, roles.length > 0
      // and at least a deploy group selected
      expect($scope.build).toBeDefined();
      expect($scope.environment).toBeDefined();
      expect($scope.roles.length).toBeGreaterThan(0);
      expect($scope.deploy_groups[0].selected).toBeUndefined();
      expect(_.some($scope.deploy_groups, $scope.isSelected)).toBe(false);

      expect($scope.validate(2)).toBe(false);
    });
  });

  describe('submit', function() {
    beforeEach(function(){
      var deferred = $q.defer();
      deferred.resolve(roles);
      spyOn(kubernetesService, 'loadRoles').and.returnValue(deferred.promise);
      $scope.buildChanged(builds[0]);
      $scope.environmentChanged(environments[0]);
      $scope.$digest();

      $scope.toggleSelection($scope.deploy_groups[0]);
    });


    it('submits the data required to create a release and handles the success scenario', function(){
      var deferred = $q.defer();
      deferred.resolve();
      spyOn(kubernetesService, 'createRelease').and.returnValue(deferred.promise);
      spyOn(notificationService, 'success');

      $scope.submit();

      $scope.$digest();

      $timeout.flush();

      var selected_deploy_groups = _.filter($scope.deploy_groups, $scope.isSelected);
      expect(kubernetesService.createRelease).toHaveBeenCalledWith('some_project', 'a build id', selected_deploy_groups);
      expect(fakeModalInstance.close).toHaveBeenCalled();
      expect(notificationService.success).toHaveBeenCalled();
    });

    it('submits the data required to create a release and handle a response error', function(){
      var deferred = $q.defer();
      deferred.reject({type: 'error', messages: ['an error', 'another error']});
      spyOn(kubernetesService, 'createRelease').and.returnValue(deferred.promise);
      spyOn(notificationService, 'error');

      $scope.submit();

      $scope.$digest();

      $timeout.flush();

      var selected_deploy_groups = _.filter($scope.deploy_groups, $scope.isSelected);
      expect(kubernetesService.createRelease).toHaveBeenCalledWith('some_project', 'a build id', selected_deploy_groups);
      expect(notificationService.error).toHaveBeenCalledWith('an error');
      expect(notificationService.error).toHaveBeenCalledWith('another error');
    });
  });
});
