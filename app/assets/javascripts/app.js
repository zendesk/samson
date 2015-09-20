var samson = angular.module("samson", [
    'templates',
    'xeditable',
    'MessageCenterModule'])
  .config(function($locationProvider) {
    $locationProvider.html5Mode({enabled: true, rewriteLinks: false, requireBase: false});
  });

samson.run(function(editableOptions) {
    editableOptions.theme = 'bs3'; // setting up bootstrap3 theme for xeditable
});

var A = angular;

A.$ = A.element;
