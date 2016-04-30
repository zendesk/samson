samson.factory("Deploys",
  [function() {
    var Deploys = {
      entries: []
    };

    return Deploys;
  }]
);

// produce label for status so they match bootstrap classes
samson.filter("visualizeStatus",
  [function() {
    return function(status) {
      return {
        "running": "primary",
        "succeeded": "success",
        "failed": "danger",
        "pending": "info",
        "cancelling": "warning",
        "cancelled": "danger",
        "errored": "danger"
      }[status];
    };
  }]
);

// display date in users preferred time format
samson.filter("timeDateFilter",
  function() {
    return function(td, timeFormat) {
      if (timeFormat === undefined || timeFormat === "") return;
      if (timeFormat == 'local') {
        return moment(td).format('LLL');
      } else if (timeFormat == 'utc') {
        return moment(td).utc().format();
      } else if (timeFormat == 'relative') {
        return moment(td).fromNow();
      } else {
        throw 'timeFormat should be one of local | utc | relative, ' + timeFormat + " provided";
      }
    };
  }
);
