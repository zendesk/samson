samson.factory('SseFactory', function($location) {
  'use strict';

  var sse = {
    connection: null,

    init: function() {
      this.connection = new EventSource($location.protocol() + '://' + $location.host() + ':' + $location.port() + '/sse');
    },

    on: function(event, callback) {
      this.connection.addEventListener(event, function(e) {
        callback(JSON.parse(e.data));
      });
    }
  };

  sse.init();
  return sse;
});
