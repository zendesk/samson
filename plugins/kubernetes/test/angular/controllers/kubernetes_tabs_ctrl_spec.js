'use strict';

describe("Controller: KubernetesTabsCtrl", function() {
  var $rootScope, $scope, $state, $stateParams, $location, controller;

  function goTo(url) {
    $location.url(url);
    $rootScope.$digest();
  }

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($controller, _$rootScope_, _$state_, _$stateParams_, _$location_, $templateCache) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $state = _$state_;
    $stateParams = _$stateParams_;
    $location = _$location_;

    $templateCache.put('kubernetes/kubernetes_releases.tmpl.html', '');
    $templateCache.put('kubernetes/dashboard.tmpl.html', '');

    controller = $controller('KubernetesTabsCtrl', {
      $rootScope: $rootScope,
      $scope: $scope
    });
  }));

  describe('navigating to /kubernetes/releases', function() {
    beforeEach(function() {
      goTo('/projects/some_project/kubernetes/releases');
    });

    it('should activate the releases tab', inject(function($q) {
      $scope.$digest();
      expect($scope.project_id).toBe('some_project');
      assertActiveTab($scope.tabs, 1);
    }));
  });

  describe('navigating to /kubernetes/dashboard', function() {
    beforeEach(function() {
      goTo('/projects/some_project/kubernetes/dashboard');
    });

    it('should activate the dashboard tab', inject(function($q) {
      $scope.$digest();
      expect($scope.project_id).toBe('some_project');
      assertActiveTab($scope.tabs, 2);
    }));
  });

  function assertActiveTab(tabs, index) {
    tabs.forEach(function(tab){
      if(tab.index == index) {
        expect(tab.active).toBe(true);
      }
      else {
        expect(tab.active).toBe(undefined);
      }
    });
  }
});
