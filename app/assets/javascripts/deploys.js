//= require typeahead.js.js
//= require changesets

var following = true; // shared with stream.js

$(function () {
  // Shows confirmation dropdown using Github comparison
  var changesetLoaded = false,
      confirmed = true,
      $container = $(".deploy-details"),
      $placeholderPanes = $container.find(".changeset-placeholder"),
      $form = $("#new_deploy"),
      $submit = $form.find('input[type=submit]'),
      $reference = $("#deploy_reference"),
      $ref_problem_list = $("#ref-problem-list"),
      $ref_status_label = $("#ref-problem-warning"),
      $messages = $("#messages");

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

  var prefetchUrl = $reference.data("prefetchUrl");

  if (prefetchUrl) {
    var engine = new Bloodhound({
      datumTokenizer: function (d) {
        return Bloodhound.tokenizers.whitespace(d.value);
      },
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      limit: 100,
      prefetch: {
        url: prefetchUrl,
        ttl: 30000,
        filter: function (references) {
          return $.map(references, function (reference) {
            return {value: reference};
          });
        }
      }
    });

    engine.initialize();

    $reference.typeahead(null, {
      display: 'value',
      source: engine.ttAdapter()
    });
  }

  // The typeahead plugin removes the focus from the input - restore it
  // after initialization.
  $reference.focus();

  // Shows commit status from Github as border color
  var timeout = null;
  var $tag_form_group = $reference.parent();

  function show_status_problems(status_list) {
    $ref_status_label.removeClass("hidden");
    $ref_problem_list.empty();
    $.each(status_list, function(idx, status) {
      if (status.state != "success") {
        $ref_problem_list.append($("<li>").text(status.state + ": " + status.description));
      }
    });
  }

  function check_status(ref) {
    $.ajax({
      url: $("#new_deploy").data("commit-status-url"),
      data: { ref: ref },
      success: function(data, status, xhr) {
        switch(data.status) {
          case "success":
            $ref_status_label.addClass("hidden");
            $tag_form_group.addClass("has-success");
            break;
          case "pending":
            $ref_status_label.removeClass("hidden");
            $tag_form_group.addClass("has-warning");
            show_status_problems(data.status_list);
            break;
          case "failure":
          case "error":
            $ref_status_label.removeClass("hidden");
            $tag_form_group.addClass("has-error");
            show_status_problems(data.status_list);
            break;
          case null:
            $ref_status_label.removeClass("hidden");
            $tag_form_group.addClass("has-error");
            show_status_problems([{"state": "Tag or SHA", description: "'" + ref + "' does not exist"}]);
            break;
        }
      }
    });
  }

  function toggleConfirmed() {
    confirmed = !confirmed;
    $submit.val(!confirmed && $form.data('confirmation') ? 'Review' : 'Deploy!');
    if (!confirmed) {
      $("#deploy-confirmation").hide();
    }
  }
  toggleConfirmed();

  $reference.keyup(function(e) {
    $ref_status_label.addClass("hidden");
    $tag_form_group.removeClass("has-success has-warning has-error");

    var ref = $(this).val();

    if(timeout) {
      clearTimeout(timeout);
    }

    if(ref !== "") {
      timeout = setTimeout(function() { check_status(ref); }, 200);
    }

    if (confirmed && e.keyCode !== 13) {
      toggleConfirmed();
    }
  });

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

  function shrinkOutput() {
    $messages.css("max-height", 550);
  }

  $("#output-follow").click(function() {
    following = true;

    shrinkOutput();

    $messages.scrollTop($messages.prop("scrollHeight"));

    $("#output-options > button, #output-grow-toggle").removeClass("active");
    $(this).addClass("active");
  });

  function growOutput() {
    $messages.css("max-height", "none");
  }

  $("#output-grow-toggle").click(function() {
    var $self = $(this);

    if($self.hasClass("active")) {
      shrinkOutput();
      $self.removeClass("active");
    } else {
      growOutput();
      $self.addClass("active");
    }
  });

  $("#output-grow").click(function() {
    growOutput();

    $("#output-options > button").removeClass("active");
    $(this).addClass("active");
    $("#output-grow-toggle").addClass("active");
  });

  $("#output-steady").click(function() {
    following = false;

    shrinkOutput();

    $("#output-options > button").removeClass("active");
    $(this).addClass("active");
  });

  // If there are messages being streamed, then show the output and hide buddy check
  $messages.bind('contentchanged', function() {
    var $output = $('#output');
    if ($output.find('.output').hasClass("hidden") ){
      $output.find('.output').removeClass('hidden');
      $output.find('.deploy-check').hide();
    }
  });

  // when user scrolls all the way down, start following
  // when user scrolls up, stop following since it would cause jumping
  // (adds 30 px wiggle room since the math does not quiet add up)
  $messages.scroll(function() {
    var position = $messages.prop("scrollHeight") - $messages.scrollTop() - $messages.height() - 30;
    if(position > 0 && following) {
      $("#output-steady").click();
    } else if (position < 0 && !following) {
      $("#output-follow").click();
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
      if ($highlightedLines) {
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
