// Stream count of current deploys to users that keep a page open via app/channels/deploy_notifications_channel.rb
// NOTE: startStream is a legacy plumbing method, there might be a better way to do this
function startStream(userId, projectParam, jobId){
  var $messages = $("#messages");
  var handlers = {
    message: function(message) {
      $messages.trigger('contentchanged');
      addLine(message);
    },
    reloaded: function() {
      waitUntilEnabled('/jobs/enabled');
    },
    viewers: function(users){
      users = users.filter(function(user) { return user.id != userId});
      if (users.length > 0) {
        var viewers = $.map(users, function(user) {
          return user.name;
        }).join(', ') + '.';

        $('#viewers-link .badge').text(users.length);
        $("#viewers").text('Other viewers: ' + viewers);
      } else {
        $('#viewers-link .badge').text(0);
        $("#viewers").text('No other viewers.');
      }
    },
    started: function(data){
      updateFavicon(data.faveicon_path);
      updateStatusAndTitle(data);
    },
    finished: function(data) {
      $messages.trigger('contentchanged');
      updateFavicon(data.favicon_path);
      updateStatusAndTitle(data);
      toggleOutputToolbar();
      timeAgoFormat();
    },
    replace: function(message){
      addLine(message, true);
    }
  };

  function addLine(message, replace) {
    if (replace) {
      $messages.children().last().remove();
    } else {
      message = "\n" + message;
    }
    $messages.append(message);
  }

  function updateFavicon(faviconPath) {
    if(!faviconPath) {
      return;
    }
    $('#favicon').attr('href', faviconPath);
  }

  function updateStatusAndTitle(data) {
    $('#header').load("/projects/" + projectParam + "/jobs/" + jobId + "?header=true", function () {
      timeAgoFormat(); // header includes new dates ... show them nicely instantly
      $(this).trigger('statusAndTitleUpdated');
    });
    window.document.title = data.title;
  }

  App.cable.subscriptions.create({channel: "JobOutputsChannel", id: jobId}, {
    received: function(payload) {
      var func = handlers[payload.event];
      if(func){
        func(payload.data)
      } else {
        alert("Handler not found for " + payload.event);
      }
    }
  });
}
