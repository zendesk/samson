// - when it looks like the user enters json ({} or []), tell them when it is invalid
// - when they correct it, clear the warning
// - when existing value is loaded, show the warning too
$(function () {
  $(".validate_whitespace").each(function(i) {
    var $value = $(this);
    var $warn = $value.next('.help-block');
    if (!$warn.length) {
      $value.after('<div class="help-block alert alert-danger"></div>')
      $warn = $value.next('.help-block');
    }

    $value.keyup(function () {
      var $value = $(this);
      var val = $value.val();

      if(/^\s*[{\[][\s\S]*[}\]]\s*$/.test(val)){
        try {
          JSON.parse(val);
          $warn.hide();
        } catch(e) {
          $warn.text('Value is not valid json ( ' + e.toString() + ' )');
          $warn.show();
        }
      } else if(/^\s+/.test(val) || /\s+$/.test(val)) {
        var $a = $('<a href="#" class="btn btn-sm btn-default">Strip Whitespace</a>').click(function(e) {
          e.preventDefault();
          $value.val($value.val().trim());
          $value.keyup();
        });
        $warn.text('Value contains excess whitespace '); // extra space to provide separation with button
        $warn.append($a);
        $warn.show();
      } else {
        $warn.hide();
      }
    }).trigger("keyup");
  });
});
