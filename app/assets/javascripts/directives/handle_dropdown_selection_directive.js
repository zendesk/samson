samson.directive('handleDropdownSelection', function($timeout) {
  return {
    restrict: 'A',
    link: function($scope, $element, attrs) {
      var searchListItem = $element.parents('li').eq(0);
      $element.on('keydown', function(e) {
        var selected = searchListItem.siblings('.selected');
        if (e.keyCode == 38 || e.keyCode == 40) { // up or down
          e.preventDefault();
          var listItems = searchListItem.siblings(':visible:not(.divider)');
          var index = -1;
          if (selected.length) {
            selected.removeClass('selected');
            index = listItems.index(selected);
          }
          listItems.eq((index + (e.keyCode - 39)) % listItems.length).addClass('selected');
        } else if (e.keyCode == 13) { // enter
          e.preventDefault();
          selected.find('a').get(0).click();
        } else {
          $timeout(function() {
            if(!selected.is(':visible')) {
              selected.removeClass('selected');
            }
          });
        }
      });
    }
  };
});
