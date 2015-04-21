describe('DeployGroupsCtrl', function() {
  beforeEach(module("samson"));

  var $rootScope,
    $scope = {},
    $controller,
    $httpBackend,
    $location,
    createController;

  beforeEach(inject(function(_$controller_, _$httpBackend_, _$location_, _$rootScope_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $scope.timeline = jasmine.createSpyObj('timeline', ['setOptions', 'getVisibleItems']);
    $scope.timeline.getVisibleItems.and.returnValue([]);
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
      $httpBackend.expectGET('/deploy_groups/1.json?page=1').respond({
        "deploys": [
          { "id": 1, "reference": "v1", "started_at": "2015-03-08", "project": { "name": "P0" }},
          { "id": 2, "reference": "v2", "created_at": "2015-03-10", "project": { "name": "P1" }}
        ]});
      $httpBackend.expectGET('/deploy_groups/1.json?page=2').respond({ "deploys": [] });
      createController();
      $httpBackend.flush();

      expect($scope.items.length).toEqual(2);
      expect($scope.items.get(1).start).toEqual(new Date("2015-03-08"));
      expect($scope.items.get(2).start).toEqual(new Date("2015-03-10"));
    });

    it('gets empty list of deploys', function() {
      $httpBackend.expectGET('/deploy_groups/1.json?page=1').respond({
        "deploys": []});
      createController();
      $httpBackend.flush();

      expect($scope.items.length).toEqual(0);
    });

    it('gets error requesting deploys', function() {
      $httpBackend.expectGET('/deploy_groups/1.json?page=1').respond(500, '');
      createController();
      $httpBackend.flush();

      expect($scope.items.length).toEqual(0);
    });

    it('adjusts start time of timeline if too few objects are visible', function() {
      $httpBackend.expectGET('/deploy_groups/1.json?page=1').respond({
        "deploys": [
          { "id": 100, "reference": "v1", "started_at": "2015-03-01"},
          { "id": 102, "reference": "v1", "started_at": "2015-03-02"},
          { "id": 103, "reference": "v1", "started_at": "2015-03-03"},
          { "id": 104, "reference": "v1", "started_at": "2015-03-04"},
          { "id": 105, "reference": "v1", "started_at": "2015-03-05"},
          { "id": 106, "reference": "v1", "started_at": "2015-03-06"},
          { "id": 107, "reference": "v1", "started_at": "2015-03-07"},
          { "id": 108, "reference": "v1", "started_at": "2015-03-08"},
          { "id": 109, "reference": "v1", "started_at": "2015-03-09"},
          { "id": 110, "reference": "v1", "started_at": "2015-03-10"},
          { "id": 111, "reference": "v1", "started_at": "2015-03-11"},
          { "id": 112, "reference": "v1", "started_at": "2015-03-12"},
          { "id": 113, "reference": "v1", "started_at": "2015-03-13"},
          { "id": 114, "reference": "v1", "started_at": "2015-03-14"},
        ]});
      $httpBackend.expectGET('/deploy_groups/1.json?page=2').respond({ "deploys": [] });
      createController();
      $scope.timeline.getVisibleItems.and.returnValue(_.range(3));
      $httpBackend.flush();
      expect($scope.timeline.setOptions).toHaveBeenCalledWith({ start : (new Date('2015-03-10')) });
    });

    it('adjusts start time of timeline if too many objects are visible', function() {
      $httpBackend.expectGET('/deploy_groups/1.json?page=1').respond({
        "deploys": [
          { "id": 100, "reference": "v1", "started_at": "2015-03-01"},
          { "id": 102, "reference": "v1", "started_at": "2015-03-02"},
          { "id": 103, "reference": "v1", "started_at": "2015-03-03"},
          { "id": 104, "reference": "v1", "started_at": "2015-03-04"},
          { "id": 105, "reference": "v1", "started_at": "2015-03-05"},
          { "id": 106, "reference": "v1", "started_at": "2015-03-06"},
          { "id": 107, "reference": "v1", "started_at": "2015-03-07"},
          { "id": 108, "reference": "v1", "started_at": "2015-03-08"},
          { "id": 109, "reference": "v1", "started_at": "2015-03-09"},
          { "id": 110, "reference": "v1", "started_at": "2015-03-10"},
          { "id": 111, "reference": "v1", "started_at": "2015-03-11"},
          { "id": 112, "reference": "v1", "started_at": "2015-03-12"},
          { "id": 113, "reference": "v1", "started_at": "2015-03-13"},
          { "id": 114, "reference": "v1", "started_at": "2015-03-14"},
          { "id": 115, "reference": "v1", "started_at": "2015-03-15"},
          { "id": 116, "reference": "v1", "started_at": "2015-03-16"},
          { "id": 117, "reference": "v1", "started_at": "2015-03-17"},
          { "id": 118, "reference": "v1", "started_at": "2015-03-18"},
          { "id": 119, "reference": "v1", "started_at": "2015-03-19"},
          { "id": 120, "reference": "v1", "started_at": "2015-03-20"},
          { "id": 121, "reference": "v1", "started_at": "2015-03-21"},
          { "id": 122, "reference": "v1", "started_at": "2015-03-22"},
          { "id": 123, "reference": "v1", "started_at": "2015-03-23"},
        ]});
      $httpBackend.expectGET('/deploy_groups/1.json?page=2').respond({ "deploys": [] });
      createController();
      $scope.timeline.getVisibleItems.and.returnValue(_.range(30));
      $httpBackend.flush();
      expect($scope.timeline.setOptions).toHaveBeenCalledWith({ start : (new Date('2015-03-20')) });
    });
  });
});
