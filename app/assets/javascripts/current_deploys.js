$(function() {
  var refresh = 5 * 1000;
  var $badge = $('.current-deploys .badge');

  var updateBadgeDisplay = function(number) {
    $badge.text(number);
    $badge.toggle(number !== 0);
  };

  var getBadgeStatus = function() {
    $.ajax({
      url: $badge.attr('data-refresh-url'),
      success: function(data) {
        updateBadgeDisplay(data.deploys.length);
        setTimeout(getBadgeStatus, refresh);
      },
      error: function(data) {
        console.log('Unable to get currently deploy count. Retrying in 60 seconds.');
        setTimeout(getBadgeStatus, 60 * 1000);
      }
    });
  };

  updateBadgeDisplay(parseInt($badge.text(), 10));
  setTimeout(getBadgeStatus, refresh);
});
