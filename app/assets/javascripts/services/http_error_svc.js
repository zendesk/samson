samson.service('httpErrorService', function() {

  this.handleResponse = function(response) {
    var messages;
    var status = response.status;

    if (status < 400) {
      throw 'Not a failed http request. Status code: ' + status;
    }
    else if (status >= 400 && status < 500) {
      messages = handleClientError(response);
    }
    else {
      messages = handleServerError();
    }

    return this.createResultType('error', messages);
  };

  this.createResultType = function(type, messages){
    if(_.isArray(messages)) {
      return {type: type, messages: messages};
    }
    else {
      return {type: type, messages: [messages]};
    }
  };

  // Client errors (400s)
  function handleClientError(response) {
    var messages = [];

    if (!_.isUndefined(response.data) && !_.isUndefined(response.data.errors)) {
      response.data.errors.map(function(error) {
        messages.push(error);
      });
    }
    else {
      messages.push(response.statusText);
    }

    return messages;
  }

  // Server errors (500s)
  function handleServerError() {
    return ['Due to a technical error, the request could not be completed. Please, try again later.'];
  }
});
