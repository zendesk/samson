samson.factory('Mentionsbox', ['$rootScope', 'Flowdock', function ($rootScope, $flowdock) {
  var self = this;
  self.users = $flowdock.users();

  self.filteredData = function (query) {
    return _.filter(self.users, function (item) {
      return item.name.toLowerCase().indexOf(query.toLowerCase()) > -1;
    });
  };

  self.markupData = function (callback) {
    $(self.mentionsId).mentionsInput('val', function(text) {
      text = text.replace(/@\[([^\\]+?)\]\(([^)]+?)\)/g, "@$1");
      callback(text);
    });
  };

  $rootScope.$on('flowdock_users', function () {
    self.draw();
  });

  self.draw = function() {
    $(self.mentionsId).mentionsInput({
      elastic: false,
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

  return {
    init: self.init
  }
}]);

samson.factory('Flowdock', ['$rootScope','$http', function ($rootScope, $http) {
  var self = this;

  self.users = function () {
    var users = [];
    var promise = $http.get('/integrations/flowdock/users');

    promise.success(function (data) {
      users.push.apply(users, data.users);
      $rootScope.$emit('flowdock_users', users);
    });

    promise.error(function () {
      console.log('Could not fetch the flowdock users!');
    });

    return users;
  };

  self.buddyRequest = function (deploy, message) {
    return $http.post('/integrations/flowdock/notify', { deploy_id: deploy, message: message });
  };

  return {
    users: self.users,
    buddyRequest: self.buddyRequest
  }
}]);

samson.controller('BuddyNotificationsCtrl', ['$scope','$rootScope', '$injector', 'Flowdock', 'Mentionsbox',
  function($scope, $rootScope, $injector, flowdock, mentionsBox) {
    $scope.title = 'Request a buddy!';
    $scope.message = null;
    $scope.successful = false;
    $scope.notificationBox = mentionsBox.init('#buddy_request_box', $scope.defaultBuddyRequestMessage);

    $scope.shouldDisplayFeedback = function() {
      return $scope.message != null;
    };

    $scope.notifyFlowDock = function () {
      $scope.notificationBox.message(function (message) {
        var result = flowdock.buddyRequest($scope.deploy, message);
        result.success(function (data) {
          $scope.message = data.message;
          $scope.successful = true
        });
        result.error(function (data) {
          $scope.message = 'Error! Could not send buddy request!';
          $scope.successful = false
        });
      });
    };
  }]).directive('buddyRequestBox', function () {
  return {
    restrict: 'E',
    templateUrl: 'directives/buddy_request_box.html',
    controller: 'BuddyNotificationsCtrl',
    scope: {
      defaultBuddyRequestMessage: '@',
      flowdockFlows: '@',
      deploy: '@'
    }
  }
});
