$(function() {
  // Refresh the page when the user stars or unstars a project.
  $('.star a').bind('ajax:complete', function() {
    window.location.reload();
  });
});
