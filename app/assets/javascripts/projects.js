// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
$(function() {
  var $stagesBox  = $("#stages"),
      $saveButton = $("#save");

  $stagesBox.sortable();
  $saveButton.on("click", function() {
    console.log($(this).data("url"));
    $.ajax({
      url: $(this).data("url"),
      data: $stagesBox.sortable("serialize", { attribute: "data-order" }),
      type: 'PUT',
    }).done(function(data) {
      console.log(data);
      console.log("success");
    }).fail(function() {
      console.log("failure");
    });
  });
});
