$(function () {
  $('a.toggle').click(function(e) {
    var target = $(this).data('target');
    $(target).toggle();
  });
});
