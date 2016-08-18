$(function() {
  // Refresh the page when the user stars or unstars a project.
  $('.star a').bind('ajax:complete', function() {
    window.location.reload();
  });

  // Show/hide docker related fields when docker checkbox is changed
  $('#project_deploy_with_docker').change(function(){
    $('#docker_release_push_field, #dockfile_field').toggle($(this).prop('checked'));
  }).triggerHandler('change');
});
