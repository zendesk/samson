$(function () {
  $('#deploy-tabs a').click(function (e) {
      e.preventDefault()
      $(this).tab('show')
  });

  $('.file-summary').click(function (e) {
    var row = $(this);
    var patch = row.next();

    patch.toggle();
  });
});
