samson.controller("ProfileCtrl",
["$scope",
function($scope) {
  $scope.toggleNotify = function($event) {
    var notificationsEnabled = $($event.target).val();

    if ( notificationsEnabled ) {
      Notification.requestPermission();
    }
  };
}]);
