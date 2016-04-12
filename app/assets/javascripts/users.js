$(function(){
  // submit form when role is selected
  $('.project_role_selector input').change(function(){
    var $form = $(this).parents('form');
    $.ajax({
      url: $form.attr('action'),
      type: $form.attr('method'),
      data: $form.serialize(),
      success: function() {
        $form.effect("highlight", {color: "#d6e9c6"}, 2000);
      },
      error: function() {
        $form.effect("highlight", {color: "#f2dede"}, 2000);
      }
    });
    return false;
  });
});
