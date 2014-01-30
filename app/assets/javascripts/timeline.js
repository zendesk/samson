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

$(function() {
  var timeArr = $(".timeline-time");
      num     = timeArr.length;

  for (var i = 0; i < num; i++) {
    var element   = timeArr.get(i);
        utcms     = element.dataset.time,
        localDate = new Date(Number.parseInt(utcms));

    element.dataset.day = localDate.getDay();
    var hour   = localDate.getHours();
        minute = localDate.getMinutes();
        ampm   = null,
        last   = null;

    if (last = timeArr.get(i - 1)) {
      if (last.dataset.day != element.dataset.day) {
        var day  = NUM_TO_DAY[localDate.getDay()],
            date = localDate.getFullYear() + " " + NUM_TO_MONTH[localDate.getMonth()] + " " + localDate.getDate();
        $(element).closest(".timeline-entry").before("<div class=\"timeline-date\">" + day + ", " + date + "</div><hr>");
      }
    }

    if (hour > 12) {
      hour -= 12;
      ampm = " PM";
    } else {
      ampm = " AM";
    }

    minute = (minute < 10) ? "0" + minute : minute;

    element.innerHTML = hour + ":" + minute + ampm;
  }
});
