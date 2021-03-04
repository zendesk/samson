// when user types into the field offer completion and show selected commit status
// TODO: show 500 errors to the user
function refStatusTypeahead(options){
  var $reference = $("#deploy_reference");
  if(!$reference.get(0)) { return; }

  function initializeTypeahead() {
    var prefetchUrl = $reference.data("prefetchUrl") || alert("prefetchUrl missing");

    var engine = new Bloodhound({
      datumTokenizer: function (d) {
        return Bloodhound.tokenizers.whitespace(d.value);
      },
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      limit: 100,
      prefetch: {
        url: prefetchUrl,
        ttl: 30000, // ms cache ttl
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
    }).focus();
  }

  // reset problem UI to default state, then apply changes
  function show_status_problems(status_list, state) {
    var $ref_status_container = $("#ref-problem-warning");
    $ref_status_container.addClass("hidden");
    $ref_status_container.removeClass('alert-danger alert-warning');

    var $tag_form_group = $reference.parent();
    $tag_form_group.removeClass("has-success has-error has-warning");

    switch(state) {
      case "default":
        return;
      case "success":
        $tag_form_group.addClass("has-success");
        return;
      case "pending": // fallthrough
      case "missing":
        $tag_form_group.addClass("has-warning");
        $ref_status_container.addClass('alert-warning');
        break;
      case "failure": // fallthrough
      case "error": // fallthrough
      case "fatal":
        $tag_form_group.addClass("has-error");
        $ref_status_container.addClass('alert-danger');
        break;
      default:
        alert("Unexpected response: " + response.toString());
        return;
    }

    $ref_status_container.removeClass("hidden");

    // show list of problems
    var $ref_problem_list = $("#ref-problem-list");
    $ref_problem_list.empty();
    $.each(status_list, function(idx, status) {
      if (status.state === "success") return;
      var item = $("<li>");
      $ref_problem_list.append(item);
      // State and status comes from GitHub or Samson,
      // safe to use .html for context/description since we sanitize in commit_statuses_controller.rb
      var description = (status.description && status.description !== "" ? status.description : status.context);
      item.html(status.state + ": " + description);
      if(status.target_url) {
        item.append(' <a href="' + status.target_url + '">details</a>');
      }
    });
  }

  // check status of reference and show user problems we found
  function check_status($field) {
    $field.addClass("loading");
    var val = $field.val();

    $.ajax({
      url: $("#new_deploy").data("commit-status-url"),
      data: { ref: val },
      success: function(response) {
        if($field.val() !== val) return; // reply from old request
        $field.removeClass("loading");
        show_status_problems(response.statuses, response.state);
      }
    });
  }

  initializeTypeahead();

  // Continuously polling for change to account for autofill which does not trigger input/change events
  // when user stops typing for a bit, we check the reference status, if user keeps typing then cancel the previous timeout
  var status_check_timeout = null;
  $reference.pollForChange(100, function() {
    show_status_problems([], "default"); // clear

    var ref = $reference.val().trim();
    $reference.val(ref); // store back trimmed value, so user sees what we see

    if(status_check_timeout) {
      clearTimeout(status_check_timeout);
    }

    if(options.changed) options.changed();

    if(ref !== "") {
      status_check_timeout = setTimeout(function() { check_status($reference); }, 200);
    }
  });

  // check initial ref on page load
  $reference.trigger('input');
}
