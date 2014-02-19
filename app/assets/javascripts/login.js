$(function() {

  $('.no-github a').click(function(){
  	$(this).parent().hide();
  	$('.action.zendesk').css('display', 'block');
  	return false;
  });

});
