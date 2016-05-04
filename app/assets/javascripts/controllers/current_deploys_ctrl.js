samson.controller("currentDeploysCtrl", function($http, SseFactory) {
  'use strict';

  SseFactory.on('deploys', function() {
    $http.get('/deploys/active?partial=true').success(function(result) {
      $('.timeline').html(result);
    });
  });
});
