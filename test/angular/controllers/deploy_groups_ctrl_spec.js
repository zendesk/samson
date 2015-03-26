describe('DeployGroupsCtrl', function() {
  beforeEach(module("samson"));

  var $rootScope,
    $scope = {},
    $controller,
    $httpBackend,
    $location,
    createController;

  beforeEach(inject(function(_$controller_, _$httpBackend_, _$location_, _$rootScope_) {
    $rootScope = _$rootScope_
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    $location = _$location_;
    createController = function() {
      $location.path('/deploy_groups/1');
      $controller = _$controller_('DeployGroupsCtrl', { $scope: $scope });
      $rootScope.$apply();
    };
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('init', function() {
    it('gets list of deploys', function() {
      $httpBackend.expectGET('/deploy_groups/1.json').respond({
        "deploys": [
          { "id": 1, "reference": "v1", "started_at": "2015-03-08", "project": { "name": "P0" }},
          { "id": 2, "reference": "v2", "created_at": "2015-03-10", "project": { "name": "P1" }}
        ]});
      createController();
      $httpBackend.flush();

      expect($scope.items.length).toEqual(2);
      expect($scope.items.get(1).start).toEqual(new Date("2015-03-08"));
      expect($scope.items.get(2).start).toEqual(new Date("2015-03-10"));
    });

    it('gets empty list of deploys', function() {
      $httpBackend.expectGET('/deploy_groups/1.json').respond({
        "deploys": []});
      createController();
      $httpBackend.flush();

      expect($scope.items.length).toEqual(0);
    });

    it('gets error requesting deploys', function() {
      $httpBackend.expectGET('/deploy_groups/1.json').respond(500, '');
      createController();
      $httpBackend.flush();

      expect($scope.items.length).toEqual(0);
    });
  });
});
