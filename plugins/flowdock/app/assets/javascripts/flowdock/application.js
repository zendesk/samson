//= require ./jquery_mentions_input/jquery.elastic.source.js
//= require ./jquery_mentions_input/jquery.mentionsInput.js

samson.factory('Mentionbox', function ($rootScope, Flowdock) {
  var self = this;
  self.users = Flowdock.users();

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

  $rootScope.$on('flowdock_users', function () {
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
    }
  };

  return self;
});

samson.factory('Flowdock', function ($rootScope, $http) {
  var self = this;

  self.users = function () {
    var users = [];

    $http.get('/flowdock/users').success(function (data) {
      users.push.apply(users, data.users);
      $rootScope.$emit('flowdock_users', users);
    }).error(function () {
      console.log('Could not fetch the flowdock users!');
    });

    return users;
  };

  self.buddyRequest = function (deploy, message) {
    return $http.post('/flowdock/notify', { deploy_id: deploy, message: message });
  };

  return {
    users: self.users,
    buddyRequest: self.buddyRequest
  }
});

samson.controller('BuddyNotificationsCtrl', function($scope, $rootScope, Flowdock, Mentionbox) {
  $scope.title = 'Request a buddy!';
  $scope.message = null;
  $scope.successful = false;
  $scope.notificationBox = Mentionbox.init('#buddy_request_box', $scope.defaultBuddyRequestMessage);

  $scope.shouldDisplayFeedback = function() {
    return $scope.message != null;
  };

  $scope.notifyFlowDock = function () {
    $scope.notificationBox.message(function (message) {
      var result = Flowdock.buddyRequest($scope.deploy, message);
      result.success(function (data) {
        $scope.message = data.message;
        $scope.successful = true
      });
      result.error(function () {
        $scope.message = 'Error! Could not send buddy request!';
        $scope.successful = false
      });
    });
  };
}).directive('buddyRequestBox', function () {
  return {
    restrict: 'E',
    templateUrl: 'templates/buddy_request_box',
    controller: 'BuddyNotificationsCtrl',
    scope: {
      defaultBuddyRequestMessage: '@',
      flowdockFlows: '@',
      deploy: '@'
    }
  }
});
