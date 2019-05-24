(function(){
  // copied from https://github.com/motdotla/dotenv/blob/master/lib/main.js
  // TODO: include via npm or rails-assets ?
  function parseEnv (src) {
    var obj = {};

    // convert Buffers before splitting into lines and processing
    src.toString().split('\n').forEach(function (line) {
      // matching "KEY' and 'VAL' in 'KEY=VAL'
      var keyValueArr = line.match(/^\s*([\w\.\-]+)\s*=\s*(.*)?\s*$/);
      // matched?
      if (keyValueArr !== null) {
        var key = keyValueArr[1];

        // default undefined or missing values to empty string
        var value = keyValueArr[2] ? keyValueArr[2] : '';

        // expand newlines in quoted values
        var len = value ? value.length : 0;
        if (len > 0 && value.charAt(0) === '"' && value.charAt(len - 1) === '"') {
          value = value.replace(/\\n/gm, '\n');
        }

        // remove any surrounding quotes and extra spaces
        value = value.replace(/(^['"]|['"]$)/g, '').trim();

        obj[key] = value;
      }
    });

    return obj;
  }

  function copyRow($row, callback) {
    var $new_row = $row.clone();
    $new_row.find(':input').val('');

    // each row needs a new unique name and id to make rails do the update logic correctly for environment_variables
    $new_row.find(':input').each(function(i, input){
      var $input = $(input);
      $.each(['id', 'name'], function(i, attr){
        if($input.attr(attr)) { // simple duplications like foo[] might not have name/id
          $input.attr(attr, $input.attr(attr).replace(/\d+/, function (n) {
            return ++n;
          }));
        }
      });
    });

    if(callback){ callback($new_row); }

    $row.after($new_row);
    return $new_row;
  }

  // Update the query string of the associated preview link
  // with the given group ID, and toggle its visibility
  function formatEnvGroupPreviewLink($preview, val) {
    $preview[0].search = $.param({ group_id: val });
    $preview.toggle(!!val);
  }

  // Select the pair of env group input and preview link to:
  // - Format the query string of the preview link
  // - Update the query string when the env group input changes
  function setupEnvGroupPreview($input) {
    var $select = $input.find('select');
    var $preview = $input.find('.checkbox a');

    $select.on('change', function(e) {
      e.preventDefault();
      formatEnvGroupPreviewLink($preview, $select.val());
    });

    $select.trigger('change');
  }

  function withoutSelectpicker($row, callback){
    var $picker = $row.find('.selectpicker');
    $picker.selectpicker('destroy').addClass('selectpicker'); // normalize existing so they are ready to copy

    var rows = callback().concat([$row]);

    // add selectpicker to copied and original rows
    $.each(rows, function(idx, $row) {
      $row.find(".selectpicker").selectpicker();
    });

    return rows;
  }

  // let user paste .env files and we parse out everything
  function parseAndAdd(pasted) {
    var env = parseEnv(pasted);

    var $row = $(".paste_env_variables").prev().prev();
    var selectedEnv = $row.find("select").val();


    withoutSelectpicker($row, function () {
      // add and fill new rows while they are not select-pickered
      // always pass the new row so rows get appended in order
      return $.map(env, function (v, k) {
        $row = copyRow($row, function ($raw_new_row) {
          var inputs = $raw_new_row.find(':input');
          $(inputs.get(0)).val(k);
          $(inputs.get(1)).val(v);
          $(inputs.get(2)).val(selectedEnv);
        });
        return $row;
      });
    });
  }

  $(document).on("click", ".duplicate_previous_row", function(e){
    e.preventDefault();
    var $row = $(this).prev();
    var rows = withoutSelectpicker($row, function(){
      return [copyRow($row)];
    });

    // Row duplication logic is reused in several places so only
    // setup the preview link for the right target.
    $.each(rows, function(idx, $row) {
      if ($row.hasClass("env_group_inputs")) {
        setupEnvGroupPreview($row);
      }
    });
  });

  $(document).on("click", ".paste_env_variables", function (e) {
    e.preventDefault();

    $("#env_paste_dialog").html("" +
      ".env format (newline separated key=val)" +
      "<textarea id='env_var_paste_area' cols='40' rows='8'></textarea>"
    );
    $("#env_paste_dialog").dialog({
      autoOpen: true,
      resizable: true,
      width: 350,
      height: 300,
      modal: true,
      title: "Paste environment variables",
      buttons: {
        "Parse": function () {
          var pasted = $("#env_paste_dialog #env_var_paste_area").val();
          parseAndAdd(pasted);
          $(this).dialog("close");
        }
      }
    });

  });

  // Display preview link dynamically when env group dropdown changes
  $(document).ready(function() {
    var $inputs = $(".env_group_inputs");

    $inputs.each(function(idx, input) {
      setupEnvGroupPreview($(input));
    });
  });
}());
