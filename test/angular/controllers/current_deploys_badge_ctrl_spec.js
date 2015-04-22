describe('currentDeployBadgeCtrl', function() {
  beforeEach(module("samson"));

  var $rootScope,
    $scope = {},
    $controller,
    $httpBackend,
    SseFactory,
    createController,
    fakeBadgeElement;

  beforeEach(inject(function(_$controller_, _$httpBackend_, _$rootScope_, _SseFactory_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    SseFactory = _SseFactory_;
    fakeBadgeElement = {
      data: function() { return '/deploys/active.json'; },
      show: jasmine.createSpy('show'),
      hide: jasmine.createSpy('hide')
    };
    spyOn(window, '$').and.returnValue(fakeBadgeElement);
    createController = function() {
      $controller = _$controller_('currentDeployBadgeCtrl', { $scope: $scope });
      $rootScope.$apply();
      $httpBackend.flush();
    };
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('init', function() {
    it('gets current active deploys', function() {
      $httpBackend.expectGET('/deploys/active.json').respond({ "deploys": [{ "id": 1 }, { "id": 2 }] });
      createController();
      expect($scope.currentActiveDeploys).toEqual(2);
      expect(fakeBadgeElement.show).toHaveBeenCalled();
    });

    it('hides badge if there are no deploys', function() {
      $httpBackend.expectGET('/deploys/active.json').respond({ "deploys": [] });
      createController();
      expect($scope.currentActiveDeploys).toEqual(0);
      expect(fakeBadgeElement.hide).toHaveBeenCalled();
    });
  });
});
