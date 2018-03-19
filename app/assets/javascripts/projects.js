$(function() {
  // switch icons when user stars or unstars a project.
  // keep in sync with app/helpers/projects_helper.rb
  $('.star.project-star').bind('ajax:success', function() {
    $(this).toggleClass('starred');
  });

  $('#project_deploy_with_docker').change(function(){
    $('#docker_release_push').toggle($(this).prop('checked'));
  }).triggerHandler('change');
});
