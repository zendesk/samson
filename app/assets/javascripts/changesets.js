$(function () {
  $("body").on("click", ".changeset-files .file-summary", function (e) {
    var row = $(this);
    var patch = row.next();

    patch.toggle();
  });
});
