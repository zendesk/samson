//= require changesets

$(function() {
  var $previousSelect;

  $('.release-list .release-summary').click(function() {
    var $this = $(this);

    if ($previousSelect && $this.get(0) !== $previousSelect.get(0)) {
      $previousSelect.removeClass('active');
      $previousSelect.next().addClass('collapse');
    }

    $this.toggleClass('active');
    $this.next().toggleClass('collapse');

    $previousSelect = $this;
  });
});
