/*
  This directive allows us to break complexity of UI Bootstrap tabs by splitting out
  the tabs contents into separate templates.
 */
samson.directive('tabContent', function() {
  return {
    restrict: 'E',
    templateUrl: function(element, attrs) {
      return attrs.templateUrl;
    }
  };
});
