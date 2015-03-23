describe('DashboardsCtrl', function() {
  beforeEach(module("samson"));

  var $controller;

  beforeEach(inject, function(_$controller_) {
    $controller = _$controller_;
  });

  describe('getProjects', function() {
    it('calls backend API for list of projects', function() {
      var $scope = {},
          controller = $controller('DashboardsCtrl', { $scope: $scope });

      expect($scope.projects).toEqual([]);
    });
  });
});
