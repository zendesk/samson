var MentionsBox = function(users) {
  var self = this;
  self.id = '#buddy_request_box';
  self.users = users;

  self.filteredData = function(query) {
    return _.filter(self.users, function (item) {
      return item.name.toLowerCase().indexOf(query.toLowerCase()) > -1
    });
  };

  self.markupData = function(callback) {
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

samson.factory('Flowdock', ['$rootScope','$http', function($rootScope, $http) {
  var self = this;

  self.users = function () {
    var users = [];
    var promise = $http.get('/integrations/flowdock/users');

    promise.success(function(data) {
      users.push.apply(users, data.users);
      $rootScope.$emit('flowdock_users', users);
    });

    promise.error(function(){
      console.log('Could not fetch the flowdock users!')
    });

    return users;
  };

  self.buddyRequest = function (deploy, message) {
    var promise = $http.post('/integrations/flowdock/notify', { deploy_id: deploy, message: message })
    promise.success(function(data) {
        $('#buddyRequestInfoBox').html('<div class="alert alert-success"><a class="close" data-dismiss="alert">×</a><span>'+ data.message + '</span></div>');
        console.log(data.message);
    });
    promise.error(function() {
      $('#buddyRequestInfoBox').html('<div class="alert alert-danger"><a class="close" data-dismiss="alert">×</a>' +
      '<span>Error! Could not send buddy request!</span></div>');
      console.log('Could not notify flows!');
    });
  };

  return {
    users: self.users,
    buddyRequest: self.buddyRequest
  }
}]);

samson.controller('BuddyNotificationsCtrl', ['$scope','$rootScope', '$injector', 'Flowdock',
  function($scope, $rootScope, $injector, flowdock) {
  var self = this;
  $scope.users = flowdock.users();
  $scope.title = 'Request a buddy!';

  self.error_getting_users = function (e) {
    console.log('Could not get users from server!');
  };

  self.initMentionsBox = function () {
    $scope.notificationBox = new MentionsBox($scope.users);
  };

  $rootScope.$on('flowdock_users', function () {
    self.initMentionsBox();
  });

  self.notifyFlowDock = function () {
    $scope.notificationBox.message(function (message) {
      flowdock.buddyRequest($scope.deploy, message);
    });
  };

}]).directive('buddyRequestBox', function () {
  return {
    restrict: 'E',
    templateUrl: 'directives/buddy_request_box.html',
    scope: {
      defaultBuddyRequestMessage: '@',
      flowdockFlows: '@',
      deploy: '@'
    }
  }
});
