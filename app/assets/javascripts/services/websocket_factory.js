samson.factory('Websocket', function($location) {
  'use strict';

  var websocket = {
    connection: null,

    init: function() {
      this.connection = new WebSocketRails($location.host() + ':' + $location.port() + '/websocket');
    },

    on: function(channel, event, callback) {
      this.connection.subscribe(channel).bind(event, callback);
    }
  };

  websocket.init();
  return websocket;
});
