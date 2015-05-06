samson.constant("MONTHS",
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

samson.constant("DAYS",
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

samson.constant('STATUS_MAPPING',
  {
    "running": "primary",
    "succeeded": "success",
    "failed": "danger",
    "pending": "info",
    "cancelling": "warning",
    "cancelled": "danger",
    "errored": "danger"
  }
);

samson.constant("StatusFilterMapping",
  {
    Successful: function(deploys) {
      return deploys.filter(function(deploy) {
        return deploy.status === "succeeded";
      });
    },

    Unsuccessful: function(deploys) {
      return deploys.filter(function(deploy) {
        return deploy.status === "failed" ||
          deploy.status === "cancelled" ||
          deploy.status === "errored";
      });
    },

    Unfinished: function(deploys) {
      return deploys.filter(function(deploy) {
        return deploy.status === "cancelling" ||
          deploy.status === "running" ||
          deploy.status === "pending";
      });
    }
  }
);

samson.filter("projectUserFilter",
  function() {
    return function(deploys, search) {
      if (typeof search == 'string' && search.length) {
        var lowerCaseSearch =  search.toLowerCase();

        return deploys.filter(function(deploy) {
          return (deploy.project.name.toLowerCase().indexOf(lowerCaseSearch) > -1 ||
              deploy.user.name.toLowerCase().indexOf(lowerCaseSearch) > -1);
        });
      }
      return deploys;
    };
  }
);

samson.filter("userFilter",
  function() {
    var hookSources = /^(?:travis|tddium|semaphore|jenkins|github)$/i;

    return function(deploys, userType) {
      if (userType !== undefined && userType !== null) {
        return deploys.filter(function(deploy) {
          return (deploy.user.name.match(hookSources) !== null) === (userType === "Robot");
        });
      }
      return deploys;
    };
  }
);

samson.filter("stageFilter",
  function() {
    return function(deploys, stageType) {
      if (stageType !== undefined && stageType !== null) {
        return deploys.filter(function(deploy) {
          return deploy.production == stageType;
        });
      }
      return deploys;
    };
  }
);

samson.filter("statusFilter",
  ["StatusFilterMapping", function(StatusFilterMapping) {
    return function(deploys, status) {
      if (status !== undefined && status !== null) {
        return StatusFilterMapping[status](deploys);
      }
      return deploys;
    };
  }]
);

samson.filter("visualizeStatus",
  ["STATUS_MAPPING", function(STATUS_MAPPING) {
    return function(status) {
      return STATUS_MAPPING[status];
    };
  }]
);

samson.filter("fullDate",
  function() {
    return function(local) {
      return local.day + ", " + local.date + " " + local.month + " " + local.year;
    };
  }
);

samson.filter("localize",
  ["DAYS", "MONTHS", function(DAYS, MONTHS) {
    return function(ms) {
      var localDate = new Date(parseInt(ms));

      var day   = DAYS[ localDate.getDay() ],
          year  = localDate.getFullYear(),
          date  = localDate.getDate(),
          month = MONTHS[ localDate.getMonth() ];

      return {
        year: year,
        month: month,
        date: date,
        day: day
      };
    };
  }]
);

samson.factory("Deploys",
  ["$filter", "$http", "$timeout", function($filter, $http, $timeout) {
    var localize = $filter("localize");

    var Deploys = {
      entries: [],
      page: 1,
      loading: false,
      theEnd: false,

      loadMore: function() {
        if (this.theEnd) { return; }

        Deploys.loading = true;

        $http.get("/deploys/recent.json", { params: { page: Deploys.page } }).
          success(function(data) {
            var deploys = data.deploys;

            if (deploys && deploys.length) {
              this.page += 1;
            } else if (deploys.length === 0) {
              this.theEnd = true;
              return;
            }

            for (var i = 0; i < deploys.length; i++) {
              deploys[i].localized_updated_at = localize(deploys[i].updated_at);
              deploys[i].updated_at_ago = moment(deploys[i].updated_at).fromNow();
              this.entries.push(deploys[i]);
            }
          }.bind(Deploys)).
          error(function() {
            alert("Failed to load more entries");
          }).
          finally(function() {
            $timeout(function() { this.loading = false; }.bind(Deploys), 500);
          });
      }
    };

    return Deploys;
  }]
);

samson.controller("TimelineCtrl", function($scope, $window, $timeout, Deploys, StatusFilterMapping, DeployHelper) {
  $scope.userTypes = ["Human", "Robot"];
  $scope.stageTypes = { "Production": true, "Non-Production": false };
  $scope.deployStatuses = Object.keys(StatusFilterMapping);
  $scope.helper = DeployHelper;
  $scope.timelineDeploys = Deploys;
  $scope.deploys = Deploys.entries;

  $scope.helper.registerScrollHelpers($scope);
  $scope.timelineDeploys.loadMore();

  $timeout(function() {
    $('select').selectpicker();
  });
});
