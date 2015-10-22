var samson = angular.module("samson", [
    'templates',
    'angular-cache',
    'MessageCenterModule'])
  .config(function($locationProvider) {
    $locationProvider.html5Mode({enabled: true, rewriteLinks: false, requireBase: false});
  });

var A = angular;

A.$ = A.element;
