samson.directive('deployGroupTimeline', function() {
  return {
    restrict: 'E',
    link: function($scope, $element) {
      var endDate = new Date(_.now() + 1*1000*60*60*24),
        options = {
        minHeight: '400px',
        max: endDate,
        end: endDate,
        showMajorLabels: false,
        showCurrentTime: false
      };

      $scope.timeline = new vis.Timeline($element[0])

      options.template = function(item) {
        return item.project.name + '<br>' + item.reference;
      };

      $scope.timeline.setItems($scope.items);
      $scope.timeline.setOptions(options);
      $scope.timeline.on('doubleClick', $scope.onDoubleClickItem);
    }
  }
});
