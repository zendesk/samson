samson.factory('SseFactory', function() {
  'use strict';

  function connect() {
    return new EventSource('/streaming');
  }

  return {
    connection: null, // needed for tests
    on: function(event, callback) {
      this.connection = this.connection || connect();
      this.connection.addEventListener(event, function(e) {
        callback(JSON.parse(e.data));
      });
    }
  };
});
