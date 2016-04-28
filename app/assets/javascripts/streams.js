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
    var doNotify = $("#output").data("desktopNotify");
    var origin = $('meta[name=deploy-origin]').first().attr('content');
    var source = new EventSource(origin + streamUrl, { withCredentials: true });

    var addLine = function(data, replace) {
      var msg = JSON.parse(data).msg;
      if (replace) {
        $messages.children().last().remove();
      } else {
        msg = "\n" + msg;
      }
      $messages.append(msg);

      if (following) {
        $messages.scrollTop($messages[0].scrollHeight);
      }
    };

    var updateStatusAndTitle = function(e) {
      var data = JSON.parse(e.data);

      $('#header').html(data.html);
      window.document.title = data.title;
      if (doNotify && data.notification !== undefined) {
        var notification = new Notification(data.notification, {icon: '/favicon.ico'});
        notification.onclick = function() { window.focus(); };
      }
    };

    source.addEventListener('append', function(e) {
      $messages.trigger('contentchanged');
      addLine(e.data);
    }, false);

    source.addEventListener('reloaded', function(e) {
      waitUntilEnabled('/jobs/enabled');
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
      addLine(e.data, true);
    }, false);

    source.addEventListener('started', function(e) {
      updateStatusAndTitle(e);
    }, false);

    source.addEventListener('finished', function(e) {
      $messages.trigger('contentchanged');

      updateStatusAndTitle(e);
      toggleOutputToolbar();
      timeAgoFormat();

      source.close();
    }, false);
  });
}
