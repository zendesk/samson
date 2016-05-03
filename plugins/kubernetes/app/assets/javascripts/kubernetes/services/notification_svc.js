samson.service('notificationService', function(messageCenterService) {

  this.info = function(message, options) {
    showMessage('info', message, options || {});
  };

  this.warning = function(message, options) {
    showMessage('warning', message, options || {});
  };

  this.error = function(message, options) {
    showMessage('danger', message, options || {});
  };

  this.success = function(message, options) {
    showMessage('success', message, options || {});
  };

  this.errors = function(messages, options) {
    showMessages('danger', messages, options || {});
  };

  this.clear = function() {
    messageCenterService.markShown();
    messageCenterService.removeShown();
  };

  /*
    Private methods
   */

  var showMessage = function(message_type, message, options) {
    messageCenterService.add(message_type, message, options);
  };

  var showMessages = function(message_type, messages, options) {
    messages.forEach(function(message) {
      messageCenterService.add(message_type, message, options);
    });
  };
});
