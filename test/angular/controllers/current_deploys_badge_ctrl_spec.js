describe('currentDeployBadgeCtrl', function() {
  beforeEach(module("samson"));

  var $rootScope,
    $scope = {},
    $controller,
    SseFactory,
    createController,
    fakeBadgeElement;

  beforeEach(inject(function(_$controller_, _$rootScope_, _SseFactory_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();
    SseFactory = _SseFactory_;
    fakeBadgeElement = {
      show: jasmine.createSpy('show'),
      hide: jasmine.createSpy('hide'),
      data: function(){ return '0' }
    };
    spyOn(window, '$').and.returnValue(fakeBadgeElement);
    createController = function() {
      $controller = _$controller_('currentDeployBadgeCtrl', { $scope: $scope });
      $rootScope.$apply();
    };
  }));

  describe('init', function() {
    it('hides badge if there are no deploys', function() {
      createController();
      expect($scope.currentActiveDeploys).toEqual(0);
      expect(fakeBadgeElement.hide).toHaveBeenCalled();
    });

    it('show badge if there are deploys', function() {
      fakeBadgeElement.data = function(){ return '1' }
      createController();
      expect($scope.currentActiveDeploys).toEqual(1);
      expect(fakeBadgeElement.show).toHaveBeenCalled();
    });
  });
});
