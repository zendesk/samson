'use strict';

describe("Controller: KubernetesReleasesCtrl", function() {
  var $rootScope, $scope, $state, $stateParams, $location, controller, $uibModal, kubernetesService, notificationService;
  var releases = [
    {
      id: 0,
      created_at: 'some_date',
      created_by: 'some_user',
      build: {
        id: 1,
        label: 'some_build'
      },
      deploy_groups: [
        {
          name: 'a_deploy_group'
        },
        {
          name: 'another_deploy_group'
        }
      ]
    }
  ];

  function goTo(url) {
    $location.url(url);
    $rootScope.$digest();
  }

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_$rootScope_, _$state_, _$stateParams_, _$location_, $templateCache, _$uibModal_, _kubernetesService_, _notificationService_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $state = _$state_;
    $stateParams = _$stateParams_;
    $location = _$location_;
    $uibModal = _$uibModal_;
    kubernetesService = _kubernetesService_;
    notificationService = _notificationService_;

    $templateCache.put('kubernetes/kubernetes_releases.tmpl.html', '');
    $templateCache.put('kubernetes/kubernetes_release_wizard.tmpl.html', '');

    // Setting up the current state and stateParams
    goTo('/projects/some_project/kubernetes/releases');
  }));

  describe('loadKubernetesReleases with a successfull response', function() {
    beforeEach(inject(function($controller, $q) {
      var deferred = $q.defer();
      deferred.resolve(releases);
      spyOn(kubernetesService, 'loadKubernetesReleases').and.returnValue(deferred.promise);

      controller = $controller('KubernetesReleasesCtrl', {
        $scope: $scope,
        $stateParams: $stateParams,
        $uibModal: $uibModal,
        kubernetesService: kubernetesService
      });
    }));

    it('should load the releases into the scope', inject(function($q) {
      $scope.$digest();
      expect(kubernetesService.loadKubernetesReleases).toHaveBeenCalled();
      expect($scope.releases[0].id).toBe(0);
      expect($scope.releases[0].build).toBeDefined();
      expect($scope.releases[0].build.id).toBe(1);
      expect($scope.releases[0].deploy_groups).toBeDefined();
      expect($scope.releases[0].deploy_groups.length).toBe(2);
      expect($scope.releases[0].deploy_groups[0].name).toBe('a_deploy_group');
      expect($scope.releases[0].deploy_groups[1].name).toBe('another_deploy_group');
    }));
  });

  describe('loadKubernetesReleases with a response error', function() {
    beforeEach(inject(function($controller, $q) {
      var deferred = $q.defer();
      deferred.reject({type: 'error', messages: ['Some technical error']});
      spyOn(kubernetesService, 'loadKubernetesReleases').and.returnValue(deferred.promise);

      controller = $controller('KubernetesReleasesCtrl', {
        $scope: $scope,
        $stateParams: $stateParams,
        kubernetesService: kubernetesService
      });
    }));

    it('should display a flash message for each error', inject(function($q) {
      spyOn(notificationService, 'error');
      $scope.$digest();
      expect(kubernetesService.loadKubernetesReleases).toHaveBeenCalled();
      expect(notificationService.error).toHaveBeenCalledWith('Some technical error');

      // Roles have not been initialised
      expect($scope.releases).toBe(undefined);
    }));
  });

  describe('$scope.showCreateReleaseDialog', function() {
    beforeEach(inject(function($controller, $q) {
      var deferred = $q.defer();
      deferred.resolve(releases);
      spyOn(kubernetesService, 'loadKubernetesReleases').and.returnValue(deferred.promise);

      controller = $controller('KubernetesReleasesCtrl', {
        $scope: $scope,
        $stateParams: $stateParams,
        $uibModal: $uibModal,
        kubernetesService: kubernetesService
      });
    }));

    it('should open the create release wizard', inject(function() {
      var expected = $uibModal.open({ template: ' '});
      spyOn($uibModal, 'open').and.returnValue(expected);

      $scope.showCreateReleaseDialog();

      expect($uibModal.open).toHaveBeenCalledWith({
        templateUrl: 'kubernetes/kubernetes_release_wizard.tmpl.html',
        controller: 'KubernetesCreateReleaseCtrl',
        size: 'lg'
      });
    }));

    it('should redirect the user to the dashboard when the dialog is closed', inject(function($timeout) {
      var expected = $uibModal.open({ template: ' '});

      spyOn($uibModal, 'open').and.returnValue(expected);
      spyOn($state, 'go');

      $scope.showCreateReleaseDialog();

      $timeout(function() {
        expected.close();
        expect($state.go).toHaveBeenCalledWith('kubernetes.dashboard');
      });
    }));

    it('should keep the user in the same screen and clear any error when the dialog is dismissed', inject(function($timeout) {
      var expected = $uibModal.open({ template: ' '});

      spyOn($uibModal, 'open').and.returnValue(expected);
      spyOn(notificationService, 'clear');

      $scope.showCreateReleaseDialog();

      $timeout(function() {
        expected.dismiss();
        expect(notificationService.clear).toHaveBeenCalled();
      });
    }));
  });
});
