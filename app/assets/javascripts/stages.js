$(function() {
  var $stagesBox = $("ul.stages"),
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
        data: {
          stage_id: $('.stages .stage-bar').map(function(){ return $(this).data('id'); }).toArray()
        },
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

  var $wantLock    = $(".want-lock"),
      $beforeLock  = $(".before-lock"),
      $description = $(".lock-description");

  $wantLock.click(function() {
    $wantLock.toggleClass("active");
    $beforeLock.toggleClass("active");
    $description.select();
  });
});
