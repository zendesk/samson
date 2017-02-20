function timeAgoFormat() {
  $("span[data-time]").each(function() {
    var utcms     = this.dataset.time,
      localDate = new Date(parseInt(utcms, 10));

    this.title = localDate.toString();
    this.innerHTML = moment(localDate).fromNow();
  });
}

$(document).ready(function() {
  timeAgoFormat();
  setInterval(timeAgoFormat, 60000); // update times every 60s
});
