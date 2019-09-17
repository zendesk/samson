// when user types into the field offer completion and show selected commit status
// TODO: show 500 errors to the user
function refStatusTypeahead(options){
  var $reference = $("#deploy_reference,#build_git_ref");
  var $build_list = $("#build_list");
  var $build_list_loading = $("#build_list_loading");
  var $form = $("#new_deploy,#new_build");
  var $ref_status_container = $("#ref-problem-warning");
  var $ref_problem_list = $("#ref-problem-list");
  var status_check_timeout = null;
  var $tag_form_group = $reference.parent();
  var $submit_button = $ref_status_container.closest('form').find(':submit');
  if(!$reference.get(0)) { return; }

  function initializeTypeahead() {
    var prefetchUrl = $reference.data("prefetchUrl");
    if (!prefetchUrl) {
      console.error('prefetchUrl missing');
      return;
    }

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
    });
  }

  function show_status_problems(status_list, isDanger) {
    $ref_status_container.removeClass("hidden");
    $ref_status_container.toggleClass('alert-danger', isDanger);
    $ref_status_container.toggleClass('alert-warning', !isDanger);

    $ref_problem_list.empty();
    $.each(status_list, function(idx, status) {
      if (status.state != "success") {
        var item = $("<li>");
        $ref_problem_list.append(item);
        // State and status comes from GitHub or Samson
        item.html(status.state + ": " + status.description);
        if(status.target_url) {
          item.append(' <a href="' + status.target_url + '">details</a>');
        }
      }
    });
  }

  function check_status(ref) {
    $submit_button.prop("disabled", false);
    $reference.addClass("loading");

    $.ajax({
      url: $form.data("commit-status-url"),
      data: { ref: ref },
      success: function(response) {
        $reference.removeClass("loading");
        switch(response.state) {
          case "success":
            $ref_status_container.addClass("hidden");
            $tag_form_group.addClass("has-success");
            break;
          case "pending":
          case "missing":
            $tag_form_group.addClass("has-warning");
            show_status_problems(response.statuses, false);
            break;
          case "failure":
          case "error":
            $tag_form_group.addClass("has-error");
            show_status_problems(response.statuses, false);
            break;
          case "fatal":
            $tag_form_group.addClass("has-error");
            $submit_button.prop("disabled", true);
            show_status_problems(response.statuses, true);
            break;
          default:
            alert("Unexpected response: " + response.toString());
            break;
        }
      }
    });
  }

  function update_builds(ref) {
    var $tbody = $build_list.find("tbody")
    $build_list.addClass("loading");

    const STATUS_MAPPING = {
      running: "pending",
      succeeded: "success",
      failed: "danger",
      errored: "danger",
      cancelling: "warning",
      cancelled: "danger"
    };

    $.ajax({
      url: $form.data("build-status-url"),
      data: { reference: ref },
      success: function(response) {
        $build_list.removeClass("loading");
        $tbody.empty();
        response.builds.forEach(function(build) {
          var label_status = "label-" + (STATUS_MAPPING[build.status] || "info");
          var build_url = $form.data("show-build-url").replace('$ID', build.id);
          $build_list_loading.addClass("hidden");
          $build_list.removeClass("hidden");

          $tbody.append(`
            <tr>
              <td class="col-sm-1"><input type="radio" name="deploy[build_id]" id="build_${build.id}" value="${build.id}" /></td>
              <td><label for="build_${build.id}">${build.name || 'Build ' + build.id}</label></td>
              <td><span data-time="${Date.parse(build.created_at)}">${build.created_at}</span></td>
              <td>${build.git_ref} (${build.git_sha && build.git_sha.slice(0,7)})</td>
              <td><a href="${build_url}"><span class="label ${label_status}">${build.status}</span></a></td>
            </tr>
          `)
        })

        timeAgoFormat();
      },
      error: function(_xhr, textStatus) {
        $build_list_loading.addClass("hidden");
        $build_list.removeClass("hidden");

        $tbody.empty();
        $tbody.append(`
            <tr>
              <td colspan="5">
                <span class="text-muted">Error fetching builds: ${textStatus}</span>
              </td>
            </tr>
          `)
      }
    });
  }

  initializeTypeahead();

  // Continuously polling for change to account for autofill which does not trigger input/change events
  $reference.pollForChange(100, function() {
    $ref_status_container.addClass("hidden");
    $tag_form_group.removeClass("has-success has-warning has-error");

    var ref = $(this).val().trim();
    $(this).val(ref); // store back trimmed value, so user sees what we see

    if(status_check_timeout) {
      clearTimeout(status_check_timeout);
    }

    if(options.changed) options.changed();

    if(ref !== "") {
      status_check_timeout = setTimeout(function() {
        update_builds(ref);
        check_status(ref);
      }, 200);
    }
  });

  // check initial ref on page load
  $reference.trigger('input');
}
