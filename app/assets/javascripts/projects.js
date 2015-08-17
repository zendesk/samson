$(function() {
  // Refresh the page when the user stars or unstars a project.
  $('.star a').bind('ajax:complete', function() {
    window.location.reload();
  });

  $('#project_deploy_with_docker').change(function(){
    $('#docker_release_push').toggle($(this).prop('checked'));
  }).triggerHandler('change');
});
