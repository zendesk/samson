describe("currentDeploysCtrl", function() {
  beforeEach(module("samson"));

  var $rootScope,
    $scope = {},
    $controller,
    $httpBackend,
    SseFactory,
    createController;

  beforeEach(inject(function(_$controller_, _$httpBackend_, _$rootScope_, _SseFactory_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    SseFactory = _SseFactory_;
    createController = function() {
      $controller = _$controller_('currentDeploysCtrl', { $scope: $scope });
      $rootScope.$apply();
    };
  }));

  it("updates deploys", function() {
    createController();

    $httpBackend.expectGET('/deploys/active?partial=true').respond("<SOME-HTML>");

    var event = document.createEvent('Event')
    event.initEvent("keypress", true, true);
    SseFactory.connection.dispatchEvent(event)
  });
});
