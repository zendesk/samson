var samson = angular.module("samson", []);

var A = angular;

A.$ = A.element;

samson.config(["$httpProvider", function($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = $('meta[name=csrf-token]').attr('content');
}]);
