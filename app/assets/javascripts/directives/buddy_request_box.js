var MentionsBox = function(users) {
  var self = this;
  self.id = '#buddy_request_box';
  self.users = users;

  self.filtered_data = function(query) {
    return _.filter(self.users, function (item) {
      return item.name.toLowerCase().indexOf(query.toLowerCase()) > -1
    });
  };

  self.markup_data = function(callback) {
    $(self.id).mentionsInput('val', function(text) {
      text = text.replace(/@\[([^\\]+?)\]\(([^)]+?)\)/g, "@$1");
      callback(text);
    });
  };

  $(self.id).mentionsInput({
    useCurrentVal: true,
    onDataRequest:function (mode, query, callback) {
      callback.call(this, self.filtered_data(query));
    }
  });

  return {
    message: self.markup_data
  }
};

samson.factory('Flowdock', ['$rootScope','$http', function($rootScope, $http) {
  var self = this;

  self.users = function () {
    var users = [];
    $http.get('/integrations/flowdock/users')
      .success(function(data) {
        users.push.apply(users, data.users);
        $rootScope.$emit('flowdock_users', users);
      }).error(function(){
        console.log('Could not fetch the flowdock users!')
      });
    return users;
  };

  self.buddy_request = function (deploy, message) {
    post_data = { deploy_id: deploy, message: message };
    $http.post('/integrations/flowdock/notify', post_data)
      .success(function(data) {
        console.log(data.message);
      }).error(function() {
        console.log('Could not notify flows!');
      });
  };

  return {
    users: self.users,
    buddy_request: self.buddy_request
  }
}]);

samson.controller('BuddyNotificationsCtrl', ['$scope','$rootScope', 'Flowdock', function($scope, $rootScope, flowdock) {
  $scope.users = flowdock.users();
  $scope.title = 'Request a buddy!';

  $scope.error_getting_users = function (e) {
    console.log('Could not get users from server!');
  };

  $scope.initMentionsBox = function () {
    $scope.notificationBox = new MentionsBox($scope.users);
  };

  $rootScope.$on('flowdock_users', function () {
    $scope.initMentionsBox();
  });

  $scope.notifyFlowDock = function () {
    $scope.notificationBox.message(function (message) {
      flowdock.buddy_request($scope.deploy, message);
    });
  };

}]).directive('buddyRequestBox', function () {
  return {
    restrict: 'E',
    controller: 'BuddyNotificationsCtrl',
    templateUrl: 'directives/buddy_request_box.html',
    scope: {
      defaultBuddyRequestMessage: '@',
      flowdockFlows: '@',
      deploy: '@'
    }
  }
});
