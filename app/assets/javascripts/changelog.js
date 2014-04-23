function getParameterByName(name) {
  var match = RegExp("[?&]" + name + "=([^&]*)").exec(window.location.search);
  return match && decodeURIComponent(match[1].replace(/\+/g, " "));
}

$(function () {
  $("#start-date").val(getParameterByName("start_date"));
  $("#end-date").val(getParameterByName("end_date"));

  $("#start-date").datepicker({ dateFormat: "yy-mm-dd"});
  $("#end-date").datepicker({ dateFormat: "yy-mm-dd"});

  $("input").change(function() {
    $("#status-message").text("Regenerating...")
    $("#date-chooser" ).submit();
  });
});
