// filter elements in a list when typing
// use by adding filter-by to an li's
// <li filter-by="fooBar">
// and having an input with that model
// <input type="search" ng-model="fooBar">
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
