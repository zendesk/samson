// Stream count of current deploys to users that keep a page open via app/channels/deploy_notifications_channel.rb
// - update deploy badge
// - reload deploys table
// - do not immediately start to avoid server overhead when user is just clicking through the UI
$(function(){
  setTimeout(function(){
    App.cable.subscriptions.create("DeployNotificationsChannel", {
      received: function(data) {
        // update deploy count in header badge
        $("#current-deploys").toggle(data.count > 0).text(data.count);

        // reload active deploys page (noop when id is not found)
        $('#deploys-active').load('/deploys/active?partial=true', function(){
          timeAgoFormat();
        });
      }
    });
  }, 5000);
});
