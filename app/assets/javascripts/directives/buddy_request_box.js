var MentionsBox = function (users) {
  var self = this;
  self.id = '#buddy_request_box';
  self.users = users;

  self.filteredData = function (query) {
    return _.filter(self.users, function (item) {
      return item.name.toLowerCase().indexOf(query.toLowerCase()) > -1;
    });
  };

  self.markupData = function (callback) {
    $(self.id).mentionsInput('val', function(text) {
      text = text.replace(/@\[([^\\]+?)\]\(([^)]+?)\)/g, "@$1");
      callback(text);
    });
  };

  $(self.id).mentionsInput({
    elastic: false,
    useCurrentVal: true,
    onDataRequest:function (mode, query, callback) {
      callback.call(this, self.filteredData(query));
    }
  });

  return {
    message: self.markupData
  }
};

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

samson.controller('BuddyNotificationsCtrl', ['$scope','$rootScope', '$injector', 'Flowdock',
  function($scope, $rootScope, $injector, flowdock) {
  $scope.users = flowdock.users();
  $scope.title = 'Request a buddy!';
  $scope.message = null;
  $scope.successful = false;

  $scope.shouldDisplayFeedback = function() {
    return $scope.message != null;
  };

  $scope.initMentionsBox = function () {
    $scope.notificationBox = new MentionsBox($scope.users);
  };

  $rootScope.$on('flowdock_users', function () {
    $scope.initMentionsBox();
  });

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
