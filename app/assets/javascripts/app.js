var samson = angular.
  module("samson", []).
  config(function($locationProvider, $httpProvider) {

    $locationProvider.html5Mode({enabled: true, rewriteLinks: false, requireBase: false});

    // submit csrf token on every request
    $httpProvider.defaults.headers.common['X-CSRF-Token'] = angular.element('meta[name=csrf-token]').attr('content');
  });


