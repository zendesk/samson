//= require typeahead.js.js
//= require changesets
//= require jquery-mentions-input/jquery.elastic.source
//= require jquery-mentions-input/jquery.mentionsInput

$(function () {
  // Shows confirmation dropdown using Github comparison
  var changesetLoaded = false,
      confirmed = true,
      $container = $(".deploy-details"),
      $placeholderPanes = $container.find(".changeset-placeholder"),
      $form = $("#new_deploy"),
      $submit = $form.find('input[type=submit]');

  // load changeset when switching to it
  $("#deploy-tabs a[data-type=github]").click(function (e) {
      e.preventDefault();
      var tab = $(this);
      tab.tab("show");

      if (!changesetLoaded) {
        var changesetUrl = $("#deploy-tabs").data("changesetUrl");

        changesetLoaded = true;

        $.ajax({
          url: changesetUrl,
          dataType: "html",
          success: function (data) {
            var container = $(".deploy-details");
            var placeholderPanes = container.find(".changeset-placeholder");

            placeholderPanes.remove();
            $('#output').after(data);

            // We need to switch to another tab and then switch back in order for
            // the plugin to detect that the DOM node has been replaced.
            $("#deploy-tabs a:first").tab("show");
            tab.tab("show");
          }
        });
      }
  });

  function toggleConfirmed() {
    confirmed = !confirmed;
    $submit.val(!confirmed && $form.data('confirmation') ? 'Review' : 'Deploy!');
    if (!confirmed) {
      $("#deploy-confirmation").hide();
    }
  }
  toggleConfirmed();

  // when changing the reference users need to check 'Review' again to get updated commit listings
  refStatusTypeahead({changed: function() { if(confirmed) { toggleConfirmed(); } }});

  function showDeployConfirmationTab($this) {
    var $navTabs = $this.find("#deploy-confirmation .nav-tabs"),
        hasActivePane = $this.find(".tab-pane.active").length === 0;

    // We need to switch to another tab and then switch back in order for
    // the plugin to detect that the DOM node has been replaced.
    $navTabs.find("a").tab("show");

    // If there is no active pane defined, show first pane
    if (hasActivePane) {
      $navTabs.find("a:first").tab("show");
    }
  }

  // When user clicks a release or deploy label, fill the deploy reference field with that version
  // also trigger version check ... see ref_status_typeahead.js
  $(".clickable-releases [data-ref]").on('click', function(event){
    event.preventDefault();
    $("#deploy_reference").val(event.target.dataset.ref).trigger('input');
  });

  $form.submit(function(event) {
    var $this = $(this);

    if(!confirmed && $this.data('confirmation')) {
      toggleConfirmed();
      $("#deploy-confirmation").show();

      showDeployConfirmationTab($this);

      $container.empty();
      $container.append($placeholderPanes);

      $.ajax({
        method: "POST",
        url: $this.data("confirm-url"),
        data: $this.serialize(),
        success: function(data) {
          $placeholderPanes.detach();
          $container.append(data);

          showDeployConfirmationTab($this);
        }
      });

      event.preventDefault();
    }
  });

  $('[data-toggle="tooltip"]').tooltip();
});

function toggleOutputToolbar() {
  $('.only-active, .only-finished').toggle();
}

function waitUntilEnabled(path) {
  $.ajax({
    url: path,
    success: function(data, status, xhr) {
      if(xhr.status == 204) {
        window.location.reload();
      }
    }
  });

  setTimeout(function() { waitUntilEnabled(path); }, 5000);
}
