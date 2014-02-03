var timeline = angular.module("timeline", [])

timeline.controller("TimelineCtrl", ["$scope", "$http", "$timeout", "$window", function($scope, $http, $timeout, $window) {
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
  };

  $scope.humanVSrobot = ["Human", "Robot"];

  $scope.userFilter = (function() {
    var hookSources = /^(?:travis|tddium|semaphore)$/i;

    return function(actual, expected) {
      if (expected) {
        var robot = hookSources.test(actual)
        if (expected == "Human") {
          return !robot;
        } else {
          return robot;
        }
      }
      return true;
    };
  })();

  $scope.production = { "Production": true, "Non-production": false };

  $scope.stageFilter = function(actual, expected) {
    if (expected !== null) {
      return actual === expected;
    }
    return true;
  };

  $scope.entries = [];
  $scope.page = 1;
  $scope.loading = false;
  $scope.theEnd = false;

  $scope.loadEntries = function() {
    if ($scope.theEnd) { return; }

    $scope.loading = true;

    $http.get("/deploys/recent.json", { params: { page: $scope.page } }).
      success(function(data) {
        if (data && data.length) {
          $scope.page += 1;
        } else if (data.length === 0) {
          $scope.theEnd = true;
          return;
        }

        for (var i = 0; i < data.length; i++) {
          data[i].time = $scope.localize(data[i].time);
          $scope.entries.push(data[i]);
        }
      }).
      error(function() {
        alert("Failed to load more entries");
      }).
      finally(function() {
        $timeout(function() { $scope.loading = false; }, 500);
      });
  };

  $scope.transformStatus = function(status) {
    return STATUS_MAPPING[status];
  };

  $scope.compareDate = function(previous, current) {
    if (previous) {
      return previous.date !== current.date ||
        previous.month !== current.month ||
        previous.year !== current.year;
    }
    return true;
  };

  $scope.dayTime = function(local) {
    return local.hour + ":" + local.minute + " " + local.ampm;
  };

  $scope.fullDate = function(local) {
    return local.day + ", " + local.year + " " + local.month + " " + local.date;
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

    if (hour >= 12) {
      if (hour > 12) { hour -= 12; }
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

  $window.onscroll = function() {
    if ($window.scrollY >= $window.scrollMaxY - 100 && !$scope.loading) {
      $scope.$apply("loadEntries()");
    }
  };

  $scope.shortWindow = function() {
    return !$scope.theEnd && $window.scrollMaxY === 0;
  };
}]);
