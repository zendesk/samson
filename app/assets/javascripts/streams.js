function timeAgoFormat() {
  $("span[data-time]").each(function() {
    var utcms     = this.dataset.time,
    localDate = new Date(parseInt(utcms, 10));

    this.title = localDate.toString();
    this.innerHTML = moment(localDate).fromNow();
  });
}

$(document).ready(timeAgoFormat);

function startStream() {
  $(document).ready(function() {
    var $messages = $("#messages");
    var streamUrl = $("#output").data("streamUrl");
    var doNotify  = $("#output").data("desktopNotify");
    var source = new EventSource(streamUrl);

    var addLine = function(data) {
      var msg = JSON.parse(data).msg;
      $messages.append(msg);
      if (following) {
        $messages.scrollTop($messages[0].scrollHeight);
      }
    };

    var updateStatusAndTitle = function(e) {
      var data = JSON.parse(e.data);

      $('#header').html(data.html);
      window.document.title = data.title;
      if ( doNotify && data.notification !== undefined) {
        var notification = new Notification(data.notification, {icon: '/favicon.ico'});
        notification.onclick = function() { window.focus(); };
      }
    };

    source.addEventListener('append', function(e) {
      $messages.trigger('contentchanged');
      addLine(e.data);
    }, false);

    source.addEventListener('reloaded', function(e) {
      setTimeout(function() { window.location.reload(); }, 5000);
    }, false);

    source.addEventListener('viewers', function(e) {
      var users = JSON.parse(e.data);

      if (users.length > 0) {
        var viewers = $.map(users, function(user) {
          return user.name;
        }).join(', ') + '.';

        $('#viewers-link .badge').html(users.length);
        $("#viewers").html('Other viewers: ' + viewers);
      } else {
        $('#viewers-link .badge').html(0);
        $("#viewers").html('No other viewers.');
      }
    }, false);

    source.addEventListener('replace', function(e) {
      $messages.children().last().remove();
      addLine(e.data);
    }, false);

    source.addEventListener('started', function(e) {
      updateStatusAndTitle(e);
    }, false);

    source.addEventListener('finished', function(e) {
      updateStatusAndTitle(e);
      toggleOutputToolbar();
      timeAgoFormat();

      source.close();
    }, false);
  });
}
