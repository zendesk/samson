samson.controller("UsersCtrl",
["$scope", "$http", "$timeout",
function($scope, $http, $timeout) {
  $scope.updateUser = function($event) {
    var userId = A.$($event.target).closest("tr").data("id"),
        roleId;

    if ($event.target.type === "radio") {
      roleId = $event.target.value;

      $http.put("/admin/users/" + userId, { role_id: roleId })
        .success(function() {
          $timeout.cancel($scope.popupCancellation);
          $scope.saveFailure = false;
          $scope.saveSuccess = true;
          $scope.popupCancellation = $timeout(function() {
            $scope.saveSuccess = null;
          }, 1500);
        })
        .error(function() {
          $timeout.cancel($scope.popupCancellation);
          $scope.saveSuccess = false;
          $scope.saveFailure = true;
          $scope.popupCancellation = $timeout(function() {
            $scope.saveFailure = null;
          }, 1500);
        });
    }
  };
}]);
