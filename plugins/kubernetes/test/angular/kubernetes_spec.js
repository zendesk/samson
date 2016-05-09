'use strict';

describe('Kubernetes ui-router config', function() {

  var $rootScope, $state, $stateParams, $location;

  function goTo(url) {
    $location.url(url);
    $rootScope.$digest();
  }

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_$rootScope_, _$state_, _$stateParams_, _$location_, $templateCache) {
    $rootScope = _$rootScope_;
    $state = _$state_;
    $stateParams = _$stateParams_;
    $location = _$location_;

    // We need add the template entry into the templateCache if we ever
    // specify a templateUrl
    $templateCache.put('kubernetes/kubernetes_roles.tmpl.html', '');
    $templateCache.put('kubernetes/kubernetes_releases.tmpl.html', '');
    $templateCache.put('kubernetes/kubernetes_edit_role.tmpl.html', '');
    $templateCache.put('kubernetes/kubernetes_create_role.tmpl.html', '');
  }));

  describe('Automatic transition to releases state', function(){
    beforeEach(inject(function(){
      goTo("/projects/some_project/kubernetes");
    }));

    it('State should have transitioned to kubernetes.releases', function() {
      expect($state.current.url).toEqual('/releases');
      expect($state.current.name).toEqual('kubernetes.releases');
    });
  });

  describe('Navigating to an unknown URL', function(){
    var project_home_url = '/projects/some_project';

    beforeEach(inject(function(){
      goTo(project_home_url);
    }));

    it('Should not transition to a valid state', function() {
      expect($state.current.name).toEqual('');
    });

    it('Should not change the URL', function() {
      expect($location.url()).toEqual(project_home_url);
    });
  });

  describe('Transition to kubernetes.roles state', function(){
    beforeEach(inject(function(){
      goTo('/projects/some_project/kubernetes/roles');
    }));

    it('State should have changed page', function() {
      expect($location.url()).toEqual('/projects/some_project/kubernetes/roles');
    });
  });

  describe('Transition to kubernetes.releases state', function(){
    beforeEach(inject(function(){
      goTo('/projects/some_project/kubernetes/releases');
    }));

    it('State should have transitioned to kubernetes.releases', function() {
      expect($state.current.name).toEqual('kubernetes.releases');
    });

    it('State data should reflect current state', function() {
      expect($state.current.data['selectedTab']).toEqual(1);
    });

    it('State views should reflect current state', function() {
      expect($state.current.views['content@']['templateUrl']).toEqual('kubernetes/kubernetes_releases.tmpl.html');
      expect($state.current.views['content@']['controller']).toEqual('KubernetesReleasesCtrl');
    });

    it('State params should reflect current state', function() {
      expect($stateParams.project_id).toEqual('some_project');
    });
  });
});
