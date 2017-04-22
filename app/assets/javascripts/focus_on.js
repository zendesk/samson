// make a link trigger focus
// <a href="#" class="focus-on" data-focus="#project_search">Something</a>
// <input id="project_search">
$(document).on('click', '.focus-on', function(){
  $($(this).data('focus')).focus();
});
