// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
$(function() {
  var $stagesBox  = $("#stages"),
      $saveButton = $("#save");

  $stagesBox.sortable();
  $saveButton.on("click", function() {
    $.ajax({
      url: $(this).data("url"),
      data: $stagesBox.sortable("serialize", { attribute: "data-id" }),
      type: 'PUT',
    }).done(function(data) {
      $("#success_message").fadeIn(200);
    }).fail(function() {
      $("#error_message").fadeIn(200);
    }).always(function() {
      setTimeout(function() {
        $(".messages").fadeOut();
      }, 2000);
    })
  });
});
