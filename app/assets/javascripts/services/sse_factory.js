samson.factory('SseFactory', function() {
  'use strict';

  var sse = {
    connection: null,

    init: function(origin) {
      this.connection = new EventSource(origin + '/streaming');
    },

    on: function(event, callback) {
      this.connection.addEventListener(event, function(e) {
        callback(JSON.parse(e.data));
      });
    }
  };

  var origin = $('meta[name=stream-origin]').first().attr('content');

  sse.init(origin);

  return sse;
});
