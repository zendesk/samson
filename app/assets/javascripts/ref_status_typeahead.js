// when user types into the field offer completion and show selected commit status
function refStatusTypeahead(options){
  var $reference = $("#deploy_reference");
  var $ref_status_container = $("#ref-problem-warning");
  var $ref_problem_list = $("#ref-problem-list");
  var status_check_timeout = null;
  var $tag_form_group = $reference.parent();
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

  function show_status_problems(status_list) {
    $ref_status_container.removeClass("hidden");
    $ref_problem_list.empty();
    $.each(status_list, function(idx, status) {
      if (status.state != "success") {
        var item = $("<li>");
        $ref_problem_list.append(item);
        item.text(status.state + ": " + status.description);
        if(status.target_url) {
          item.append(' <a href="' + status.target_url + '">details</a>');
        }
      }
    });
  }

  function check_status(ref) {
    $.ajax({
      url: $("#new_deploy").data("commit-status-url"),
      data: { ref: ref },
      success: function(response) {
        switch(response.status) {
          case "success":
            $ref_status_container.addClass("hidden");
            $tag_form_group.addClass("has-success");
            break;
          case "pending":
            $tag_form_group.addClass("has-warning");
            show_status_problems(response.status_list);
            break;
          case "failure":
          case "error":
            $tag_form_group.addClass("has-error");
            show_status_problems(response.status_list);
            break;
          default:
            alert("Unexpected response: " + response.toString());
            break;
        }
      }
    });
  }

  initializeTypeahead();

  $reference.on('input', function(e) {
    $ref_status_container.addClass("hidden");
    $tag_form_group.removeClass("has-success has-warning has-error");

    var ref = $(this).val().trim();
    $(this).val(ref); // store back trimmed value, so user sees what we see

    if(status_check_timeout) {
      clearTimeout(status_check_timeout);
    }

    if(ref !== "") {
      status_check_timeout = setTimeout(function() { check_status(ref); }, 200);
    }
  });
}
