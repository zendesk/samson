$(function() {
  var $stagesBox = $("#stages"),
      $messages  = $(".messages"),
      $successs  = $("#success_message"),
      $error     = $("#error_message");

  $stagesBox.sortable();

  var reorderCtrl = {
    reorder:    reorder,
    timeout:    null,
    sending:    false,
    needResend: false
  };

  function reorder() {
    $.ajax({
      url:  $stagesBox.data("url"),
      data: $stagesBox.sortable("serialize", { attribute: "data-id" }),
      type: "PUT",
    }).done(function(data) {
      clearTimeout(reorderCtrl.timeout);
      $successs.fadeIn(200);
    }).fail(function() {
      clearTimeout(reorderCtrl.timeout);
      $error.fadeIn(200);
    }).always(function() {
      if (reorderCtrl.needResend) {
        $messages.hide();
        reorderCtrl.reorder();
        reorderCtrl.needResend = false;
      } else {
        reorderCtrl.sending = false;
      }

      reorderCtrl.timeout = setTimeout(function() {
        $messages.fadeOut(300);
      }, 2000);
    })
  }

  $stagesBox.sortable({
    update: function() {
      if (reorderCtrl.sending) {
        reorderCtrl.needResend = true;
      } else {
        reorderCtrl.sending = true;
        reorderCtrl.reorder();
      }
    }
  });
});
