$(function() {
  // Refresh the page when the user stars or unstars a project.
  $('.star a').bind('ajax:complete', function() {
    window.location.reload();
  });

  $('.deployment-alert').each(function(e) {
    var url, html, reference, timestamp, user;
    url = $(this).data('url');
    reference = $(this).data('reference');
    timestamp = $(this).data('timestamp');;
    user = $(this).data('user');
    html = '<div class="container">' +
             '<div class="span4">' +
               '<a href="' + url + '" class="label label-warning"> ' + reference + '</a>' +
              '<small> at ' + timestamp + ' by ' + user + ' </small>' +
             '</div>' +
           '</div>';

    $(this).popover({
        html: true,
        content: html,
        template: '<div class="popover deployment-alert-popover"><div class="arrow"></div><div class="popover-inner"><h3 class="popover-title"></h3><div class="popover-content"><p></p></div></div></div>'

    });
  });

});
