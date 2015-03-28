samson.directive('filterBy', function($parse) {
  return {
    restrict: 'A',
    link: function($scope, $element, attrs) {
      var model = $parse(attrs.filterBy);
      $scope.$watch(model, function(value) {
        var matches = !value || (new RegExp(value, 'i')).test($element.text());
        $element.toggle(matches);
      });
    }
  };
});
