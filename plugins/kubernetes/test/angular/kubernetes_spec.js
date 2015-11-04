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
    $templateCache.put('kubernetes/kubernetes_release_groups.tmpl.html', '');
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

    it('State should have transitioned to kubernetes.roles', function() {
      expect($state.current.name).toEqual('kubernetes.roles');
    });

    it('State data should reflect current state', function() {
      expect($state.current.data['selectedTab']).toEqual(0);
    });

    it('State views should reflect current state', function() {
      expect($state.current.views['content@']['templateUrl']).toEqual('kubernetes/kubernetes_roles.tmpl.html');
      expect($state.current.views['content@']['controller']).toEqual('KubernetesRolesCtrl');
    });

    it('State params should reflect current state', function() {
      expect($stateParams.project_id).toEqual('some_project');
    });
  });

  describe('Transition to kubernetes.roles.edit state', function(){
    beforeEach(inject(function(){
      goTo('/projects/some_project/kubernetes/roles/1/edit');
    }));

    it('State should have transitioned to kubernetes.roles.edit', function() {
      expect($state.current.name).toEqual('kubernetes.roles.edit');
    });

    it('State data should reflect current state', function() {
      expect($state.current.data['selectedTab']).toEqual(0);
    });

    it('State views should reflect current state', function() {
      expect($state.current.views['content@']['templateUrl']).toEqual('kubernetes/kubernetes_edit_role.tmpl.html');
      expect($state.current.views['content@']['controller']).toEqual('KubernetesEditRoleCtrl');
    });

    it('State params should reflect current state', function() {
      expect($stateParams.project_id).toEqual('some_project');
      expect($stateParams.role_id).toEqual('1');
    });
  });

  describe('Transition to kubernetes.roles.create state', function(){
    beforeEach(inject(function(){
      goTo('/projects/some_project/kubernetes/roles/new');
    }));

    it('State should have transitioned to kubernetes.roles.create', function() {
      expect($state.current.name).toEqual('kubernetes.roles.create');
    });

    it('State data should reflect current state', function() {
      expect($state.current.data['selectedTab']).toEqual(0);
    });

    it('State views should reflect current state', function() {
      expect($state.current.views['content@']['templateUrl']).toEqual('kubernetes/kubernetes_create_role.tmpl.html');
      expect($state.current.views['content@']['controller']).toEqual('KubernetesCreateRoleCtrl');
    });

    it('State params should reflect current state', function() {
      expect($stateParams.project_id).toEqual('some_project');
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
      expect($state.current.views['content@']['templateUrl']).toEqual('kubernetes/kubernetes_release_groups.tmpl.html');
      expect($state.current.views['content@']['controller']).toEqual('KubernetesReleaseGroupsCtrl');
    });

    it('State params should reflect current state', function() {
      expect($stateParams.project_id).toEqual('some_project');
    });
  });
});
