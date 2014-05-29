//= require changesets

$(function() {
  var $previousSelect;

  $('.release-list .release-summary').click(function(e) {
    var $this = $(this);
    var $target = $(e.target);

    if ($target.parents('.btn-group').length == 1 || $target.is('.release-label')) {
      // One of the buttons on the row was clicked, don't toggle details.
      return;
    }

    if ($previousSelect && $this.get(0) !== $previousSelect.get(0)) {
      $previousSelect.removeClass('active');
      $previousSelect.next().addClass('collapse');
    }

    $this.toggleClass('active');
    $this.next().toggleClass('collapse');

    $previousSelect = $this;
  });
});
