//= require changesets

$(function() {
  var $previous_select = null;

  $('.release-list .release-summary').click(function() {
    var $this = $(this);

    if ($previous_select && $this[0] !== $previous_select[0]) {
      $previous_select.removeClass('active');
      $previous_select.next().addClass('collapse');
    }

    $this.toggleClass('active');
    $this.next().toggleClass('collapse');

    $previous_select = $this;
  });
});
