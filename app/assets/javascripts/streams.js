function startStream() {
  $(document).ready(function() {
    var $messages = $("#messages");
    var streamUrl = $("#output").data("streamUrl");
    var doNotify = $("#output").data("desktopNotify");
    var source = new EventSource(streamUrl, { withCredentials: true });

    function addLine(data, replace) {
      var msg = JSON.parse(data).msg;
      if (replace) {
        $messages.children().last().remove();
      } else {
        msg = "\n" + msg;
      }
      $messages.append(msg);
    }

    function updateFavicon(faviconPath) {
      if(!faviconPath) {
        return;
      }
      $('#favicon').attr('href', faviconPath);
    }

    function updateStatusAndTitle(data) {
      $('#header').html(data.html);
      timeAgoFormat(); // header includes new dates ... show them nicely instantly
      window.document.title = data.title;
      if (doNotify && data.notification !== undefined) {
        var notification = new Notification(data.notification, {icon: '/favicon.ico'});
        notification.onclick = function() { window.focus(); };
      }
    }

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
      var data = JSON.parse(e.data);
      updateFavicon(data.faveicon_path);
      updateStatusAndTitle(data);
    }, false);

    source.addEventListener('finished', function(e) {
      $messages.trigger('contentchanged');
      var data = JSON.parse(e.data);
      updateFavicon(data.favicon_path);
      updateStatusAndTitle(data);
      toggleOutputToolbar();
      timeAgoFormat();

      source.close();
    }, false);
  });
}
