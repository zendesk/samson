describe('DashboardsCtrl', function() {
  beforeEach(module("samson"));

  var $scope = {},
    $controller,
    $httpBackend;

  beforeEach(inject(function(_$controller_, _$httpBackend_) {
    $scope = {};
    $httpBackend = _$httpBackend_;
    $httpBackend.expectGET('//deploy_groups').respond({ deploy_groups: [{id: '1'}]});
    $httpBackend.expectGET('/projects.json').respond({ projects: [{id:1,name:"P0",url:"/projects/p0"},{id:2,name:"P1",url:"/projects/p1"}]});
    $httpBackend.expectGET('/projects/p0/deploy_group_versions.json?').respond({"1":{id:1,reference:"v1",url:"/projects/example-project/deploys/1"}});
    $httpBackend.expectGET('/projects/p1/deploy_group_versions.json?').respond({"1":{id:1,reference:"v2",url:"/projects/example-project/deploys/2"}});
    $controller = _$controller_('DashboardsCtrl', { $scope: $scope });
    $httpBackend.flush();
  }));

  describe('getProjects', function() {
    it('gets list of deploy groups', function() {
      expect($scope.deploy_groups).toEqual([{id: '1'}]);
    });

    it('calls backend API for list of projects', function() {
      expect(_.pluck($scope.projects, 'name')).toEqual(['P0', 'P1']);
    });

    it('gets deploy version v1 for P0', function() {
      expect($scope.projects[0].name).toEqual('P0');
      expect(_.pluck($scope.projects[0].deploy_group_versions, 'reference')).toEqual(['v1']);
    });
  });
});
