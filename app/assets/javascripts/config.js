samson.config(["$httpProvider", function($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = A.$('meta[name=csrf-token]').attr('content');
}]);
