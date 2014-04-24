$(function () {
  $("#start-date").datepicker({ dateFormat: "yy-mm-dd"});
  $("#end-date").datepicker({ dateFormat: "yy-mm-dd"});

  $("input").change(function() {
    $("#status-message").text("Regenerating...")
    $("#date-chooser" ).submit();
  });
});
