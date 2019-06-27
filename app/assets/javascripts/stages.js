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

  $(".env-toggle-all").each(function() {
    var envCheckbox = $(this);
    var deploygroupCheckboxes = $("." + envCheckbox.data('target'));
    var updateEnv = function(){ setEnvironmentCheckbox(envCheckbox, deploygroupCheckboxes); };

    envCheckbox.change(function(e) {
      deploygroupCheckboxes.prop("checked", $(e.target).prop('checked'));
    });

    // Update top-level checkboxes if user selects subset of deploy groups
    deploygroupCheckboxes.change(updateEnv);

    // set initial state
    updateEnv();
  });

  function setEnvironmentCheckbox(envCheckbox, deploygroupCheckboxes) {
    var checks = _.uniq(_.pluck(deploygroupCheckboxes, 'checked'));

    if (checks.length == 2) { // some items checked
      envCheckbox.prop('indeterminate', true);
    } else { // all or none checked
      envCheckbox.prop('checked', checks[0]);
      envCheckbox.prop('indeterminate', false);
    }
  }
});
