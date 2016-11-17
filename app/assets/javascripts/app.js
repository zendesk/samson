var samson = angular.module("samson", [
    'templates',
    'MessageCenterModule',
    'angularSpinner',
    'ui.router',
    'truncate'])
  .config(function($locationProvider, $httpProvider, usSpinnerConfigProvider) {

    $locationProvider.html5Mode({enabled: true, rewriteLinks: false, requireBase: false});

    $httpProvider.defaults.headers.common['X-CSRF-Token'] = A.$('meta[name=csrf-token]').attr('content');

    // Theme configuration for the spinners
    // See: https://github.com/urish/angular-spinner
    usSpinnerConfigProvider.setTheme('async-data-loader', {color: '#333', radius: 10});
  });

var A = angular;

A.$ = A.element;


