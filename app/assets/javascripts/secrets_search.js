// We hash the secret values the user types before sending it to the server.
//
// We don't want to send secrets to the server in plaintext and we don't want to keep secret values in the user's
// browser. We also never want to hash a blank values or values that have already been hashed.
// Since this is a password field, and the user cannot see what they are typing might end up editing a hashed value
// thinking it's a real value, and so we clear the field when the user clicks on it.

$(function () {
  var needsHashing = false;
  var secretValue = $('#search_value_hashed');
  var secretForm = secretValue.parents('form');
  var secretBase = secretForm.data('secret-base');

  secretValue.focus(function () {
    if(needsHashing) {
      return;
    }

    needsHashing = true;
    secretValue.val('');
  });

  secretForm.submit(function () {
    var val = secretValue.val();

    if(val === '' || !needsHashing) {
      return;
    }

    // Shared logic between ruby and js Must always be kept in sync with lib/samson/secrets/manager.rb#hash_value
    var shaObject = new jsSHA("SHA-256", "TEXT");
    shaObject.update(secretBase + val);
    secretValue.val(shaObject.getHash("HEX").substring(0, 10));
  });
});
