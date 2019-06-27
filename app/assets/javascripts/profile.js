// ask for permission to use desktop notifications when user enabled desktop notification in profile
$(document).on("change", "#user_desktop_notify", function(){
  if ($(this).is(":checked")) {
    Notification.requestPermission();
  }
});
