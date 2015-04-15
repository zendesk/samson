samson.directive('deployGroupTimeline', function() {
  return {
    restrict: 'E',
    link: function($scope, $element) {
      var endDate = moment().add(1, 'days'),
          options = {
            max: endDate,
            end: endDate,
            showCurrentTime: false
          };

      $scope.timeline = new vis.Timeline($element[0]);

      options.template = function(item) {
        return item.project.name + '<br>' + item.reference;
      };

      $scope.timeline.setItems($scope.items);
      $scope.timeline.setOptions(options);
      $scope.timeline.on('doubleClick', $scope.onDoubleClickItem);
    }
  };
});
