// filter elements in a list when typing
// use by adding a class to an li's
// <li class="filtered-projects">
// and having an input targetting it
// <input type="search" class="filter-list" data-target=".filtered-projects">
$(function(){
  $('.filter-list').on('keyup', function(){
    var $list = $($(this).data('target'));
    var typed = $(this).val();
    $list.each(function(i, element){
      var $element = $(element);
      var matches = !typed || (new RegExp(typed, 'i')).test($element.text());
      $element.toggle(matches);
    });
  });
});
