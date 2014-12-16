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

samson.filter("userFilter",
  function() {
    var hookSources = /^(?:travis|tddium|semaphore|jenkins)$/i;

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

      var day    = DAYS[localDate.getDay()],
        year   = localDate.getFullYear(),
        date   = localDate.getDate(),
        month  = MONTHS[localDate.getMonth()];

      return {
        year: year,
        month: month,
        date: date,
        day: day
      };
    };
  }]
);
