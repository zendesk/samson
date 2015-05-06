describe("currentDeploysCtrl", function() {
  beforeEach(module("samson"));

  var $rootScope,
    $scope = {},
    $controller,
    $httpBackend,
    SseFactory,
    DeployHelper,
    createController;

  beforeEach(inject(function(_$controller_, _$httpBackend_, _$rootScope_, _SseFactory_, _DeployHelper_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    SseFactory = _SseFactory_;
    DeployHelper = _DeployHelper_;
    createController = function() {
      $controller = _$controller_('currentDeploysCtrl', { $scope: $scope });
      $rootScope.$apply();
      $httpBackend.flush();
    };
  }));

  it("should have get 1 active deploy", function() {
    $httpBackend.expectGET('/deploys/active.json').respond({
      "deploys": [
        { "id": 1, "updated_at": 1412847908000, "summary": "testsummary" }
      ]
    });
    createController();
    expect($scope.deploys).toEqual([
      { id : 1, updated_at : 1412847908000, summary : 'testsummary', updated_at_ago : moment(1412847908000).fromNow() }
    ]);
  });

  it("should have get 0 active deploys", function() {
    $httpBackend.expectGET('/deploys/active.json').respond({
      "deploys": []
    });
    createController();
    expect($scope.deploys).toEqual([]);
  });

  it("should update deploys with new deploy", function() {
    $httpBackend.expectGET('/deploys/active.json').respond({
      "deploys": []
    });
    createController();
    expect($scope.deploys).toEqual([]);
    $scope.addDeploy({ "id": 1, "updated_at": 1412847908000, "summary": "testsummary" });
    expect($scope.deploys).toEqual([
      { id : 1, updated_at : 1412847908000, summary : 'testsummary' }
    ]);
  });

  it("should update deploys with removed deploy", function() {
    $httpBackend.expectGET('/deploys/active.json').respond({
      "deploys": [
        { "id": 1, "updated_at": 1412847908000, "summary": "testsummary" }
      ]
    });
    createController();
    expect($scope.deploys).toEqual([
      { id : 1, updated_at : 1412847908000, summary : 'testsummary', updated_at_ago : moment(1412847908000).fromNow() }
    ]);
    $scope.removeDeploy({ "id": 1 });
    expect($scope.deploys).toEqual([]);
  });

  it("should update deploys with updated deploy", function() {
    $httpBackend.expectGET('/deploys/active.json').respond({
      "deploys": [
        { "id": 1, "updated_at": 1412847908000, "summary": "testsummary" }
      ]
    });
    createController();
    expect($scope.deploys).toEqual([
      { id : 1, updated_at : 1412847908000, summary : 'testsummary', updated_at_ago : moment(1412847908000).fromNow() }
    ]);
    $scope.updateDeploy({ "id": 1, "updated_at": 1412847908000, "summary": "new" });
    expect($scope.deploys).toEqual([
      { id : 1, updated_at : 1412847908000, summary : 'new' }
    ]);
  });
});
