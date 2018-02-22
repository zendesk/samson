// Governs the lock/warning form. Users can use either the buttons for quickly setting the
// lock/warning duration or a datetime picker for setting a custom value.

$(function () {
  var datetimeFormat = 'MM/DD/YYYY h:mm A';

  function formatLockExpirationTime(form, lockDeleteAtInput) {
    form.submit(function (e) {
      var lockDeleteAtVal = lockDeleteAtInput.val();

      if (lockDeleteAtVal !== '') {
        var lockExpireMoment = moment(lockDeleteAtVal, datetimeFormat);
        lockDeleteAtInput.val(lockExpireMoment.utc().format());
      }
    });
  }

  function handleLockTimeButtons(lockExpirationTimeButtons, lockDeleteAtInput) {
    // user clicks on pre-defined lock time buttons
    lockExpirationTimeButtons.click(function (e) {
      var buttonData = e.target.dataset;
      var unit = buttonData.unit;
      var quantity = parseInt(buttonData.num, 10);

      if (quantity === 0) {
        lockDeleteAtInput.val('');
      } else {
        var newVal = moment().add(quantity, unit).format(datetimeFormat);
        lockDeleteAtInput.val(newVal);
      }
    });
  }

  $('.datetimepicker').datetimepicker();

  $('.new-lock-form').each(function() {
    var form = $(this);
    var lockDeleteAtInput = form.find('#lock_delete_at');
    var lockExpirationTimeButtons = form.find('.lock-times');

    formatLockExpirationTime(form, lockDeleteAtInput);
    handleLockTimeButtons(lockExpirationTimeButtons, lockDeleteAtInput);
  });
});
