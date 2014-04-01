$(function () {
  $(".changeset-files").on("click", ".file-summary", function (e) {
    var row = $(this);
    var patch = row.next();

    patch.toggle();
  });
});
