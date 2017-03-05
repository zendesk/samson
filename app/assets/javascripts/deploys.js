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

  // When user clicks a release label, fill the deploy reference field with that version
  $("#recent-releases .release-label").on('click', function(event){
    event.preventDefault();
    // Get version number from link href
    var version = event.target.href.substring(event.target.href.lastIndexOf('/') + 1);
    $("#deploy_reference").val(version);
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

  (function() {
    var HASH_REGEX = /^#L(\d+)(?:-L(\d+))?$/;
    var $highlightedLines;
    var LINES_SELECTOR = '#messages span';

    function linesFromHash() {
      var result = HASH_REGEX.exec(window.location.hash);
      if (result === null) {
        return [];
      } else {
        return result.slice(1);
      }
    }

    function addHighlight(start, end) {
      if (!start) {
        return;
      }
      start = Number(start) - 1;
      if (end) {
        end = Number(end);
      } else {
        end = start + 1;
      }
      $highlightedLines = $(LINES_SELECTOR).slice(start, end).addClass('highlighted');
    }

    function removeHighlight() {
      if ($highlightedLines) {
        $highlightedLines.removeClass('highlighted');
      }
    }

    function highlightAndScroll() {
      highlight();
      scroll();
    }

    function scroll() {
      if ($highlightedLines && $highlightedLines.get(0)) {
        $highlightedLines.get(0).scrollIntoView(true);
      }
    }

    function highlight() {
      removeHighlight();
      var nextLines = linesFromHash();
      addHighlight.apply(this, nextLines);
    }

    function indexOfLine() {
      // the jQuery map passes an index before the element
      var line = arguments[arguments.length - 1];
      return $(line).index(LINES_SELECTOR) + 1;
    }

    $('#messages').on('click', 'span', function(event) {
      if ($(event.target).is('a')) { return; } // let users click on links
      event.preventDefault();
      var clickedNumber = indexOfLine($(event.currentTarget));
      var shift = event.shiftKey;
      if (shift && $highlightedLines.length) {
        var requestedLines = $highlightedLines.map(indexOfLine);
        requestedLines.push(clickedNumber);
        requestedLines = requestedLines.sort(function(a, b) {
          return a - b;
        });
        var end = requestedLines.length - 1;
        window.location.hash = 'L' + requestedLines[0] + '-L' + requestedLines[end];
      } else {
        window.location.hash = 'L' + clickedNumber;
      }
      highlight();
    });

    highlightAndScroll();
  }());

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
