var samson = angular.module("samson", [
    'templates',
    'MessageCenterModule',
    'angularSpinner',
    'ui.router',
    'ui.bootstrap',
    'truncate'])
  .config(function($locationProvider, usSpinnerConfigProvider) {
    $locationProvider.html5Mode({enabled: true, rewriteLinks: false, requireBase: false});

    // Theme configuration for the spinners
    // See: https://github.com/urish/angular-spinner
    usSpinnerConfigProvider.setTheme('async-data-loader', {color: '#333', radius: 10})
  });

var A = angular;

A.$ = A.element;
