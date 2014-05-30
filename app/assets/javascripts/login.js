$(function() {

  $('.no-github a').click(function(){
    $(this).parent().hide();
    $('.more-login-actions').css('display', 'block');
    return false;
  });

});
