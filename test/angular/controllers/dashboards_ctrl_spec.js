describe('DashboardsCtrl', function() {
  beforeEach(module("samson"));

  var $scope = {},
    $controller,
    $httpBackend,
    createController;

  beforeEach(inject(function(_$controller_, _$httpBackend_) {
    $scope = {};
    $httpBackend = _$httpBackend_;
    createController = function() {
      $controller = _$controller_('DashboardsCtrl', { $scope: $scope });
    };
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('init', function() {
    var project0_versions_response;

    beforeEach(function() {
      $httpBackend.expectGET('//deploy_groups').respond({ deploy_groups: [{id: '1'}, {id: '2'}]});
      $httpBackend.expectGET('/projects.json')
        .respond({ projects: [{id:1,name:"P0",url:"/projects/p0"},{id:2,name:"P1",url:"/projects/p1"}]});
      project0_versions_response = $httpBackend.expectGET('/projects/p0/deploy_group_versions.json')
        .respond({"1":{id:1,reference:"v1"}});
      $httpBackend.expectGET('/projects/p1/deploy_group_versions.json')
        .respond({"1":{id:1,reference:"v2"}, "2":{id:1,reference:"v3"}});
    });

    it('gets list of deploy groups', function() {
      createController();
      $httpBackend.flush();
      expect($scope.deploy_groups).toEqual([{id: '1'}, {id: '2'}]);
    });

    it('gets list of projects', function() {
      createController();
      $httpBackend.flush();
      expect(_.pluck($scope.projects, 'name')).toEqual(['P0', 'P1']);
    });

    it('gets deploy version v1 for P0', function() {
      createController();
      $httpBackend.flush();
      expect($scope.projects[0].name).toEqual('P0');
      expect(_.pluck($scope.projects[0].deploy_group_versions, 'reference')).toEqual(['v1']);
    });

    it('gets deploy version v2,v3 for P1', function() {
      createController();
      $httpBackend.flush();
      expect($scope.projects[1].name).toEqual('P1');
      expect(_.pluck($scope.projects[1].deploy_group_versions, 'reference')).toEqual(['v2', 'v3']);
    });

    it('ignore deploy groups not in environment for project', function() {
      project0_versions_response.respond({"1":{id:1,reference:"v1"}, "999":{id:2,reference:"v999"}});
      createController();
      $httpBackend.flush();
      expect(_.pluck($scope.projects[0].deploy_group_versions, 'reference')).toEqual(['v1']);
    });
  });

  describe('getProjects', function() {
    beforeEach(function() {
      $httpBackend.expectGET('//deploy_groups').respond({ deploy_groups: [{id: '1'}]});
    });

    it('gets empty list of projects', function() {
      $httpBackend.expectGET('/projects.json').respond({ projects: []});
      createController();
      $httpBackend.flush();
      expect(_.pluck($scope.projects, 'name')).toEqual([]);
    });

    it('gets empty list of projects with 404', function() {
      $httpBackend.expectGET('/projects.json').respond(500, '');
      createController();
      $httpBackend.flush();
      expect(_.pluck($scope.projects, 'name')).toEqual([]);
    });
  });

  describe('getProjectsCss', function() {
    beforeEach(function() {
      $httpBackend.expectGET('//deploy_groups').respond({ deploy_groups: [{id: '1'}, {id: '2'}]});
      $httpBackend.expectGET('/projects.json').respond({ projects: [{id:1,name:"P0",url:"/projects/p0"}]});
    });

    it('has no class for same version on all deploy groups', function() {
      $httpBackend.expectGET('/projects/p0/deploy_group_versions.json').respond({"1":{reference:"v1"}, "2":{reference:"v1"}});
      createController();
      $httpBackend.flush();
      expect($scope.projects[0].css.tr_class).toBeUndefined();
    });

    it('has warning class for different versions', function() {
      $httpBackend.expectGET('/projects/p0/deploy_group_versions.json').respond({"1":{reference:"v1"}, "2":{reference:"v2"}});
      createController();
      $httpBackend.flush();
      expect($scope.projects[0].css.tr_class).toEqual('warning');
    });

    it('has no-deploys and display-none for project without versions', function() {
      $httpBackend.expectGET('/projects/p0/deploy_group_versions.json').respond({});
      createController();
      $httpBackend.flush();
      expect($scope.projects[0].css.tr_class).toEqual('no-deploys');
      expect($scope.projects[0].css.style).toEqual('display: none;');
    });
  });
});
