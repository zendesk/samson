$(function() {
  var $stagesBox = $("#stages"),
      $messages  = $(".messages"),
      $successs  = $("#success_message"),
      $error     = $("#error_message");

  var reorderCtrl = {
    sending:               false,
    orderChanged:          false,
    messageFadeOutTimeout: null,

    reorder: function() {
      $.ajax({
        url:  $stagesBox.data("url"),
        data: $stagesBox.sortable("serialize", { attribute: "data-id" }),
        type: "PATCH",
      }).done(function(data) {
        clearTimeout(reorderCtrl.messageFadeOutTimeout);
        $successs.fadeIn(200);
      }).fail(function() {
        clearTimeout(reorderCtrl.messageFadeOutTimeout);
        $error.fadeIn(200);
      }).always(function() {
        if (reorderCtrl.orderChanged) {
          $messages.hide();
          reorderCtrl.reorder();
          reorderCtrl.orderChanged = false;
        } else {
          reorderCtrl.sending = false;
        }

        reorderCtrl.messageFadeOutTimeout = setTimeout(function() {
          $messages.fadeOut(300);
        }, 2000);
      });
    }
  };

  if ($stagesBox.data("sortable")) {
    $stagesBox.sortable({
      update: function() {
        if (reorderCtrl.sending) {
          reorderCtrl.orderChanged = true;
        } else {
          reorderCtrl.sending = true;
          reorderCtrl.reorder();
        }
      }
    });
  }

  $(".want-lock").not(":disabled").click(function() {
    var $form = $(this).next();
    $(this).toggleClass("active");
    $form.toggleClass("active");
    $form.find(".lock-description").select();
  });
});
