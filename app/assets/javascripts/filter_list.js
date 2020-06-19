// filter elements in a list when typing
// use by adding a class to an li's
// <li class="filtered-projects">
// and having an input targetting it
// <input type="search" class="filter-list" data-target=".filtered-projects" data-default="/foo">
$(document).on('keyup', 'input.filter-list', function(e){
  var $list = $($(this).data('target'));
  var selected_class = 'selected';
  var selected = $list.filter('.' + selected_class);

  if (e.keyCode == 38 || e.keyCode == 40) { // up or down ... move selected class
    e.preventDefault();

    var direction = (e.keyCode - 39); // -1 or 1
    var selectable = $list.filter(':visible');
    var index = selectable.index(selected);

    selected.removeClass(selected_class);
    selectable.eq((index + direction) % selectable.length).addClass(selected_class);
  } else if (e.keyCode == 13) { // enter
    e.preventDefault();
    if(selected.length === 0) {
      window.location.href = $(this).data('default'); // nothing selected ... go to default
    } else {
      selected.find('a').get(0).click();
    }
  } else { // filter elements by typing
    var typed = $(this).val();
    $list.each(function(i, element){
      var $element = $(element);
      var matches = (new RegExp(typed, 'i')).test($element.text());
      $element.toggle(matches);
    });
  }
});
