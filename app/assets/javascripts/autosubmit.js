$(function(){
  // submit form when input is changed
  $('form.autosubmit input').on('change', function(){
    var $form = $(this).parents('form');
    $.ajax({
      url: $form.attr('action'),
      type: $form.attr('method'),
      data: $form.serialize(),
      success: function() {
        $form.effect("highlight", {color: "#d6e9c6"}, 2000);
      },
      error: function() {
        $form.effect("highlight", {color: "#ff5555"}, 10000);
      }
    });
    return false;
  });
});
