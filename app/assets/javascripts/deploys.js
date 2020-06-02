//= require typeahead.js.js
//= require changesets
//= require jquery-mentions-input/jquery.elastic.source
//= require jquery-mentions-input/jquery.mentionsInput

$(function () {
  // Lazy-load changeset tabs when clicked
  // Note this is using bootstrap tabs not jquery UI tabs library
  // https://getbootstrap.com/docs/3.4/javascript/#tabs-methods

  var activeTab,
      changesetLoaded = false,
      confirmed = true,
      $container = $(".deploy-details"),
      $placeholderPanes = $container.find(".changeset-placeholder"),
      $form = $("#new_deploy"),
      $submit = $form.find('input[type=submit]');

  // load changeset when switching to it (for deploy#show)
  $("#deploy-tabs a[data-toggle=tab][href^='#']").click(function (e) {
      e.preventDefault();

      var $tab = $(this);
      var $placeholder = $container.find('.changeset-placeholder');
      $tab.tab("show");

      // abort if already loaded (either static or via previous changeset load)
      if ($container.find($tab.attr('href')).length) { return; }

      // prevent double-loading
      if (!changesetLoaded) {
        $placeholder.show();
        $container.find('.tab-pane').removeClass('active');

        var changesetUrl = $("#deploy-tabs").data("changesetUrl");

        changesetLoaded = true;

        $.ajax({
          url: changesetUrl,
          dataType: "html",
          success: function (data) {
            $placeholder.hide()

            $('#output').after(data);

            // We need to switch to another tab and then switch back in order for
            // the plugin to detect that the DOM node has been replaced.
            $("#deploy-tabs a:first").tab("show");
            $tab.tab("show");
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

  // when changing the reference users need to 'Review' again to see updated commit listings
  refStatusTypeahead({changed: function() { if(confirmed) { toggleConfirmed(); } }});

  function storeActiveTab($this) {
    activeTab = $this.find('.nav-tabs li.active a').attr('href');
  }

  function showActiveTab($this) {
    var $navTabs = $this.find("#deploy-confirmation .nav-tabs");
    var tabToMakeActive = $navTabs.find('[href="' + activeTab + '"]');

    // We need to switch to another tab and then switch back in order for
    // the plugin to detect that the DOM node has been replaced.
    $navTabs.find("a").tab("show");

    if(tabToMakeActive.length !== 0) {
      tabToMakeActive.tab('show');
    } else {
      $navTabs.find("a:first").tab("show");
    }
  }

  function showChangeset($form) {
    toggleConfirmed();
    $("#deploy-confirmation").show();

    storeActiveTab($form);

    $('.changeset-content').remove();
    $('.changeset-placeholder').addClass('active')
    $container.append($placeholderPanes);

    $.ajax({
      method: "POST",
      url: $form.data("confirm-url"),
      data: $form.serialize(),
      success: function (data) {
        $placeholderPanes.detach();
        $container.append(data);
        showActiveTab($form);
      }
    });
  }

  // When user clicks a release or deploy label, fill the deploy reference field with that version
  // also trigger version check ... see ref_status_typeahead.js
  $(".clickable-releases [data-ref]").on('click', function(event){
    event.preventDefault();
    $("#deploy_reference").val(event.target.dataset.ref).trigger('input');
  });

  $form.submit(function(event) {
    var $form = $(this);

    if(!confirmed && $form.data('confirmation')) { // user pressed `Review`: load in changeset
      event.preventDefault();
      showChangeset($form);
    } else { // user pressed `Deploy!`: start the deploy
      $form.find("input[type=submit]").prop("disabled",true) // prevent accidental clicks
    }
  });

  $('[data-toggle="tooltip"]').tooltip();
});

function toggleOutputToolbar() {
  $('.only-active, .only-finished').toggle();
}

function waitUntilEnabled(path) {
  setInterval(function() {
    $.ajax({
      url: path,
      success: function(data, status, xhr) {
        if(xhr.status == 204) {
          window.location.reload();
        }
      }
    });
  }, 5000);
}
