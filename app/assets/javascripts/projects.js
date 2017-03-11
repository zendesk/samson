$(function() {
  // switch icons when user stars or unstars a project.
  // keep in sync with app/helpers/projects_helper.rb
  $('.star a').bind('ajax:success', function() {
    $(this).toggleClass('glyphicon-star-empty');
    $(this).toggleClass('glyphicon-star');
  });

  $('#project_deploy_with_docker').change(function(){
    $('#docker_release_push').toggle($(this).prop('checked'));
  }).triggerHandler('change');
});
