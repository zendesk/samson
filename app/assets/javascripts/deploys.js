//= require typeahead

$(function () {
  var changesetLoaded = false;

  $('#deploy-tabs a').click(function (e) {
      e.preventDefault();
      var tab = $(this);
      tab.tab('show');

      if (!changesetLoaded) {
        var changesetUrl = $('#deploy-tabs').data('changesetUrl');

        changesetLoaded = true;

        $.ajax({
          url: changesetUrl,
          dataType: "html",
          success: function (data) {
            var container = $(".deploy-details");
            var placeholderPanes = container.find(".changeset-placeholder");

            placeholderPanes.remove();
            container.append(data);

            // We need to switch to another tab and then switch back in order for
            // the plugin to detect that the DOM node has been replaced.
            $("#deploy-tabs a:first").tab('show');
            tab.tab('show');
          }
        });
      }
  });

  $('.deploy-details').on('click', '.file-summary', function (e) {
    var row = $(this);
    var patch = row.next();

    patch.toggle();
  });

  $("span[data-time]").each(function() {
    var utcString = this.dataset.time,
    localDate     = new Date(utcString);
    $(this).attr('title', localDate);
  })

  var prefetchUrl = $("#deploy_reference").data("prefetchUrl");

  $("#deploy_reference").typeahead({
    name: "releases",
    prefetch: prefetchUrl
  });
});
