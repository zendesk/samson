samson.service('notificationService', function(messageCenterService) {
  this.info = function(message, options) {

    showMessage('info', message, options);
  };

  this.warning = function(message, options) {
    showMessage('warning', message, options);
  };

  this.error = function(message, options) {
    showMessage('danger', message, options);
  };

  this.success = function(message, options) {
    showMessage('success', message, options);
  };

  this.errors = function(messages, options) {
    showMessages('danger', messages, options);
  };

  function showMessage(message_type, message, options) {
    messageCenterService.markShown();
    messageCenterService.removeShown();
    messageCenterService.add(message_type, message, options);
  }

  function showMessages(message_type, messages, options) {
    messageCenterService.markShown();
    messageCenterService.removeShown();

    messages.forEach(function(message) {
      messageCenterService.add(message_type, message, options);
    });
  }
});
