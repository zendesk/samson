// filter elements in a list when typing
// use by adding a class to an li's
// <li class="filtered-projects">
// and having an input targetting it
// <input type="search" class="filter-list" data-target=".filtered-projects">
$(document).on('keyup', 'input.filter-list', function(e){
  var $list = $($(this).data('target'));
  var selected = $list.filter('.selected');

  // select by using up/down arrow and enter
  if (e.keyCode == 38 || e.keyCode == 40) { // up or down ... move selected class
    e.preventDefault();

    var direction = (e.keyCode - 39); // -1 or 1
    var selectable = $list.filter(':visible:not(.divider)');
    var index = selectable.index(selected);

    selected.removeClass('selected');
    selectable.eq((index + direction) % selectable.length).addClass('selected');
  } else if (e.keyCode == 13) { // enter
    e.preventDefault();
    selected.find('a').get(0).click();
  } else { // filter elements by typing
    var typed = $(this).val();
    $list.each(function(i, element){
      var $element = $(element);
      var matches = (new RegExp(typed, 'i')).test($element.text());
      $element.toggle(matches);
    });

    // hide selected if we filtered it
    if(!selected.is(':visible')) { selected.removeClass('selected'); }
  }
});
