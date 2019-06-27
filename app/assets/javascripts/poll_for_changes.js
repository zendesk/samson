$.fn.pollForChange = function (interval, callback) {
  var self = this;
  var lastValue = "";

  setInterval(function () {
      var newValue = $(self).val();
      if (newValue !== lastValue) {
        lastValue = newValue;
        callback.call(self);
      }
    },
    interval
  );
};
