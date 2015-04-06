//= require typeahead
//= require changesets

var following = true;
$(function () {
  // Shows confirmation dropdown using Github comparison
  var changesetLoaded = false,
      confirmed = true,
      $container = $(".deploy-details"),
      $placeholderPanes = $container.find(".changeset-placeholder"),
      $form = $("#new_deploy"),
      $submit = $form.find('input[type=submit]'),
      $reference = $("#deploy_reference");
      $ref_status_label = $("#ref-problem-warning");

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
      source: engine.ttAdapter()
    });
  }

  // The typeahead plugin removes the focus from the input - restore it
  // after initialization.
  $reference.focus();

  // Shows commit status from Github as border color
  var timeout = null;
  var tag_form_group = $reference.parent();

  function check_status(ref) {
    $.ajax({
      url: $("#new_deploy").data("commit-status-url"),
      data: { ref: ref },
      success: function(data, status, xhr) {
        if(data.status == "pending") {
          $ref_status_label.addClass("hidden");
          tag_form_group.addClass("has-warning");
        } else if(data.status == "success") {
          $ref_status_label.addClass("hidden");
          tag_form_group.addClass("has-success");
        } else if(data.status == "failure" || data.status == "error") {
          $ref_status_label.removeClass("hidden");
          tag_form_group.addClass("has-error");
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
    tag_form_group.removeClass("has-success has-warning has-error");

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

  $form.submit(function(event) {
    var $selected_stage = $("#deploy_stage_id option:selected"),
        $this = $(this),
        $submit = $this.find('button[type=submit]');

    if(!confirmed && $this.data('confirmation')) {
      toggleConfirmed();
      $("#deploy-confirmation").show();
      $("#deploy-confirmation .nav-tabs a:first").tab("show");
      $container.empty();
      $container.append($placeholderPanes);


      $.ajax({
        method: "POST",
        url: $this.data("confirm-url"),
        data: $this.serialize(),
        success: function(data, status, xhr) {
          $placeholderPanes.detach();
          $container.append(data);

          // We need to switch to another tab and then switch back in order for
          // the plugin to detect that the DOM node has been replaced.
          $('#deploy-confirmation .nav-tabs a').tab("show");
          $('#deploy-confirmation .nav-tabs a:first').tab("show");
        }
      });

      event.preventDefault();
    }
  });

  function shrinkOutput() {
    $("#messages").css("max-height", 550);
  }

  $("#output-follow").click(function(event) {
    following = true;

    shrinkOutput();

    var $messages = $("#messages");
    $messages.scrollTop($messages.prop("scrollHeight"));

    $("#output-options > button, #output-grow-toggle").removeClass("active");
    $(this).addClass("active");
  });

  function growOutput() {
    $("#messages").css("max-height", "none");
  }

  $("#output-grow-toggle").click(function(event) {
    var $self = $(this);

    if($self.hasClass("active")) {
      shrinkOutput();
      $self.removeClass("active");
    } else {
      growOutput();
      $self.addClass("active");
    }
  });

  $("#output-grow").click(function(event) {
    growOutput();

    $("#output-options > button").removeClass("active");
    $(this).addClass("active");
    $("#output-grow-toggle").addClass("active");
  });

  $("#output-steady").click(function(event) {
    following = false;

    shrinkOutput();

    $("#output-options > button").removeClass("active");
    $(this).addClass("active");
  });

  // If there are messages being streamed, then show the output and hide buddy check
  $('#messages').bind('contentchanged', function(){
    var $output = $('#output');
    if ($output.find('.output').hasClass("hidden") ){
      $output.find('.output').removeClass('hidden');
      $output.find('.deploy-check').hide();
    }
  });

});

function toggleOutputToolbar() {
  $('.only-active, .only-finished').toggle();
}
