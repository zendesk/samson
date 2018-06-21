$(function () {
  // navigate to the correct tab if we opened this page with a hash/fragment/anchor
  if(window.location.hash !== "") {
    $('.nav-tabs a[href="' + window.location.hash + '"]').trigger('click');
  }

  // when clicking a tab with a hash href, apply that hash to the location to make url copy-pasting possible
  $('.nav-tabs a[href^="#"]').click(function(){
    window.location.hash = this.hash;
  });

  // Initialize popover tooltips in tab when tab is shown
  $('a[data-toggle="tab"]').on('shown.bs.tab', function() {
    $('.tab-content i[data-toggle="popover"]').popover();
  });
});
