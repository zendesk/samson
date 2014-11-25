$(function() {
  // Refresh the page when the user stars or unstars a project.
  $('.star a').bind('ajax:complete', function() {
    window.location.reload();
  });

  $('.deployment-alert').mouseover(function(e) {

    $(this).tooltip()
  });

});




samson.directive('myPane', function() {
    return {
        restrict: 'E',
        transclude: true,
        templateUrl: 'my-dialog.html'

    };
});
