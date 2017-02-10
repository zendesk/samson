//= require changesets

$(function() {
  var $previous;

  function toggle(item, remove) {
    item.toggleClass('active', remove);
    item.next().toggleClass('collapse', remove);
  }

  $('.release-list .release-summary').click(function(e) {
    var $this = $(this);

    // don't show details when user wants to navigate
    if ($(e.target).is('a,button')) { return; }

    // hide previous
    if ($previous && $this.get(0) !== $previous.get(0)) {
      toggle($previous, true);
    }

    // show and load content if necessary
    toggle($this);
    var insert = $this.next().find('td:last-child');
    if(insert.is(':empty')) {
      insert.responsiveLoad($this.next().data('url'));
    }

    $previous = $this;
  });
});
