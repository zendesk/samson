samson.controller("UsersCtrl",
["$scope", "$http", "$timeout",
function($scope, $http, $timeout) {
  var SUCCESS = "<div class=\"save-success\">Saved</div>",
      FAILURE = "<div class=\"save-failure\">Failed</div>";

  $scope.updateUser = function($event) {
    var roleTd  = A.$($event.target).closest(".role"),
        wrapper = roleTd.find(".relative-wrapper"),
        userId  = roleTd.data("user-id"),
        showStatus = function(text){
          $(text).appendTo(wrapper).delay(1500).fadeOut(500, function() {
            this.remove();
          });
        },
        roleId;

    if ($event.target.type === "radio") {
      roleId = $event.target.value;

      $http.put("/admin/users/" + userId, { user: { role_id: roleId } })
        .success(function() { showStatus(SUCCESS); })
        .error(function() { showStatus(FAILURE); });
    }
  };
}]);
