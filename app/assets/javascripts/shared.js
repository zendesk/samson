$(function () {
  $('a.toggle').click(function(e) {
    e.preventDefault();
    var target = $(this).data('target');
    $(target).toggle();
  });
});
