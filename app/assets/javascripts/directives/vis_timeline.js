samson.directive('visTimeline', function() {
  return {
    restrict: 'E',
    link: function($scope, $element) {
      var timeline = new vis.Timeline($element[0]);
      timeline.setItems($scope.items);
      timeline.setOptions($scope.options);
      timeline.on('select', $scope.onItemSelect);
    }
  }
});
