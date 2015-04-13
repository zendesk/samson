$(function () {
  $("#start-date").datepicker({ dateFormat: "yy-mm-dd"});
  $("#end-date").datepicker({ dateFormat: "yy-mm-dd"});

  $("input").change(function() {
    $("#status-message").removeClass("hidden").text("Regenerating...");
    $("#date-chooser" ).submit();
  });
});
