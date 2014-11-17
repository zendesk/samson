samson.factory('DeployHelper', ['$window', '$log', 'Deploys', function($window, $log, Deploys) {
  var helper = {
    registerScrollHelpers: function(scope) {
      angular.element($window).on("scroll", (function() {
        var html = document.querySelector("html");
        return function() {
          if ($window.scrollY >= html.scrollHeight - $window.innerHeight - 100 && !Deploys.loading) {
            scope.$apply(Deploys.loadMore.call(Deploys));
          }
        };
      })());
    },

    jumpTo: function(url) {
      $log.info("Jumpto Called: " + url);
      $window.location.href = url;
    },

    shortWindow: function() {
      return !Deploys.theEnd && $window.scrollMaxY === 0;
    }
  }

  return helper;
}]);

