$(function() {
  var $badge = $('.current-deploys .badge');

  var updateBadgeDisplay = function(number) {
    if (number != undefined) { $badge.text(number); }

    if (parseInt($badge.text()) > 0) {
      $badge.removeClass('hide');
    } else {
      $badge.addClass('hide');
    }
  };

  var getBadgeStatus = function() {
    $.ajax({
      url: $badge.attr('data-refresh-url'),
      success: function(data) {
        updateBadgeDisplay(data.deploys.length);
        setTimeout(getBadgeStatus, 5000);
      },
      error: function(data) {
        console.log('Unable to get currently deploy count. Retrying in 60 seconds.');
        setTimeout(getBadgeStatus, 60000);
      }
    });
  };

  updateBadgeDisplay();
  getBadgeStatus();
});
