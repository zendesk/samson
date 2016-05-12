// make a link trigger focus
// <a href="#" focus-on="{ click: '#project_search' }">Something</a>
// <input id="project_search">
samson.directive('focusOn', function($timeout, $parse) {
  return {
    restrict: 'A',
    link: function($scope, $element, attrs) {
      var model = $parse(attrs.focusOn)();
      Object.keys(model).forEach(function(event) {
        $element.on(event, function() {
          $timeout(function() {
            $(model[event]).focus();
          });
        });
      });
    }
  };
});
