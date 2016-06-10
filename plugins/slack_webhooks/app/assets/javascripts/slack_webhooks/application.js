//= require jquery_mentions_input/jquery.elastic.source.js
//= require jquery_mentions_input/jquery.mentionsInput.js

samson.factory('SlackMentionbox', function ($rootScope, Slack) {
  var self = this;
  self.users = Slack.users();

  self.filteredData = function (query) {
    return _.filter(self.users, function (item) {
      return item.name.toLowerCase().indexOf(query.toLowerCase()) > -1;
    });
  };

  self.markupData = function (callback) {
    $(self.mentionsId).mentionsInput('val', function(text) {
      text = self.reformatMessage(text);
      callback(text);
    });
  };

  self.reformatMessage = function(text) {
    return text.replace(/@\[([^\\]+?)\]\(([^)]+?)\)/g, "@$1");
  };

  $rootScope.$on('slack_webhooks_users', function () {
    self.draw();
  });

  self.draw = function() {
    $(self.mentionsId).mentionsInput({
      defaultValue: self.defaultMessage,
      onDataRequest:function (mode, query, callback) {
        callback.call(this, self.filteredData(query));
      }
    });
  };

  self.init = function(id, defaultMessage) {
    self.mentionsId = id;
    self.defaultMessage = defaultMessage;
    self.draw();
    return {
      message: self.markupData
    };
  };

  return self;
});

samson.factory('Slack', function ($rootScope, $http) {
  var self = this;

  self.users = function () {
    var users = [];

    $http.get('/slack_webhooks/users').success(function (data) {
      users.push.apply(users, data.users);
      $rootScope.$emit('slack_webhooks_users', users);
    }).error(function () {
      console.log('Could not fetch the Slack users!');
    });

    return users;
  };

  self.buddyRequest = function (deploy, message) {
    return $http.post('/slack_webhooks/notify', { deploy_id: deploy, message: message });
  };

  return {
    users: self.users,
    buddyRequest: self.buddyRequest
  };
});

samson.controller('SlackBuddyNotificationsCtrl', function($scope, $rootScope, Slack, SlackMentionbox) {
  $scope.message = null;
  $scope.successful = false;
  $scope.notificationBox = SlackMentionbox.init('#buddy_request_box', $scope.defaultBuddyRequestMessage);

  $scope.shouldDisplayFeedback = function() {
    return $scope.message !== null;
  };

  $scope.notify = function() {
    $scope.notificationBox.message(function(message) {
      var result = Slack.buddyRequest($scope.deploy, message);

      result.then(function(response) {
        $scope.message = response.data.message;
        $scope.successful = true;
      });

      result.catch(function() {
        $scope.message = 'Error! Could not send buddy request!';
        $scope.successful = false;
      });
    });
  };
}).directive('slackBuddyRequestBox', function () {
  return {
    restrict: 'E',
    templateUrl: 'templates/buddy_request_box',
    controller: 'SlackBuddyNotificationsCtrl',
    scope: {
      defaultBuddyRequestMessage: '@',
      channels: '@',
      deploy: '@'
    }
  };
});
