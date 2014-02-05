pusher.constant("MONTHS",
  [
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
  ]
);

pusher.constant("DAYS",
  [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  ]
);

pusher.constant('STATUS_MAPPING',
  {
    "running": "primary",
    "succeeded": "success",
    "failed": "danger",
    "pending": "default",
    "cancelling": "warning",
    "cancelled": "danger"
  }
);

pusher.filter("userFilter",
  function() {
    var hookSources = /^(?:travis|tddium|semaphore)$/i;

    return function(deploys, userType) {
      if (userType !== undefined && userType !== null) {
        return deploys.filter(function(deploy) {
          return (deploy.user.match(hookSources) !== null) === (userType === "Robot");
        });
      }
      return deploys;
    };
  }
);

pusher.filter("stageFilter",
  function() {
    return function(deploys, stageType) {
      if (stageType !== undefined && stageType !== null) {
        return deploys.filter(function(deploy) {
          return deploy.stageType == stageType;
        });
      }
      return deploys;
    };
  }
);

pusher.filter("transformStatus",
  ["STATUS_MAPPING", function(STATUS_MAPPING) {
    return function(status) {
      return STATUS_MAPPING[status];
    };
  }]
);

pusher.filter("dayTime",
  function() {
    return function(local) {
      return local.hour + ":" + local.minute + " " + local.ampm;
    };
  }
);

pusher.filter("fullDate",
  function() {
    return function(local) {
      return local.day + ", " + local.year + " " + local.month + " " + local.date;
    };
  }
);

pusher.controller("TimelineCtrl", ["$scope", "$http", "$timeout", "$window", "MONTHS", "DAYS", "STATUS_MAPPING",
function($scope, $http, $timeout, $window, MONTHS, DAYS, STATUS_MAPPING) {
  $scope.userTypes = ["Human", "Robot"];

  $scope.stageTypes = { "Production": true, "Non-production": false };

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

  $scope.isSameDate = function(previous, current) {
    if (previous) {
      return previous.date === current.date &&
        previous.month === current.month &&
        previous.year === current.year;
    }
    return false;
  };

  $scope.localize = function(ms) {
    var localDate = new Date(Number.parseInt(ms));

    var hour   = localDate.getHours(),
        minute = localDate.getMinutes(),
        day    = DAYS[localDate.getDay()],
        year   = localDate.getFullYear(),
        date   = localDate.getDate(),
        month  = MONTHS[localDate.getMonth()],
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

  angular.element($window).on("scroll", function() {
    if ($window.scrollY >= $window.scrollMaxY - 100 && !$scope.loading) {
      $scope.$apply($scope.loadEntries);
    }
  });

  $scope.shortWindow = function() {
    return !$scope.theEnd && $window.scrollMaxY === 0;
  };
}]);
