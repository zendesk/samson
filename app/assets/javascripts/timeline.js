var timeline = angular.module('timeline', [])

timeline.controller('TimelineCtrl', ['$scope', '$http', function($scope, $http) {
  var NUM_TO_MONTH = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ];

  var NUM_TO_DAY = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  ];

  var STATUS_MAPPING = {
    "running": "primary",
    "succeeded": "success",
    "failed": "danger",
    "pending": "default",
    "cancelling": "warning",
    "cancelled": "danger"
  }

  $scope.entries = [];
  $scope.page = 1;

  $scope.loadEntries = function() {
    $http.get("/deploys/recent.json", { params: { page: $scope.page } }).
      success(function(data) {
        if (data) { $scope.page += 1; }

        for (var i = 0; i < data.length; i++) {
          data[i].time = $scope.localize(data[i].time);
          $scope.entries.push(data[i]);
        }
      }).
      error(function() {
        alert("Failed to load more entries");
      });
  };

  $scope.transformStatus = function(status) {
    return STATUS_MAPPING[status];
  };

  $scope.dayTime = function(local) {
    return local.hour + ":" + local.minute + " " + local.ampm;
  };

  $scope.localize = function(ms) {
    var localDate = new Date(Number.parseInt(ms));

    var hour   = localDate.getHours(),
        minute = localDate.getMinutes(),
        day    = NUM_TO_DAY[localDate.getDay()],
        year   = localDate.getFullYear(),
        date   = localDate.getDate(),
        month  = NUM_TO_MONTH[localDate.getMonth()],
        ampm   = null;

    if (hour > 12) {
      hour -= 12;
      ampm = "PM";
    } else {
      ampm = "AM";
    }

    minute = (minute < 10) ? "0" + minute : minute;

    return {
      hour: hour,
      minute: minute,
      ampm: ampm,
      year: year,
      month: month,
      date: date,
      day: day
    };
  };

  $scope.loadEntries();
}]);
