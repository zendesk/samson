// Lock/warning dialog
// - use buttons to set predefined duration
// - datetime picker to set a custom value

$(function () {
  var datetimePickerFormat = 'MM/DD/YYYY h:mm A';
  var never = '';
  var dialog = '.lock-dialog';

  // user opens the a dropdown via bootstrap.js for the first time: initialize it
  $(document).one('shown.bs.dropdown', dialog, function () {
    var form = $(this, 'form');
    var deleteAtInput = form.find('#lock_delete_at');

    // initialize date-picker UI
    $('.datetimepicker', this).datetimepicker();

    // user clicks on pre-defined lock time buttons (2 hours / 1 day etc)
    form.find('.lock-times').click(function (e) {
      var buttonData = e.target.dataset;
      var quantity = parseInt(buttonData.num, 10);

      if (quantity === 0) {
        deleteAtInput.val(never);
      } else {
        // pretend the data-picker set it
        deleteAtInput.val(moment().add(quantity, buttonData.unit).format(datetimePickerFormat));
      }
    });

    // user submits the form: covert datetimepicker value to backend expected date format
    form.submit(function () {
      var lockDeleteAtVal = deleteAtInput.val();
      if (lockDeleteAtVal !== never) {
        var expireMoment = moment(lockDeleteAtVal, datetimePickerFormat);
        deleteAtInput.val(expireMoment.utc().format());
      }
    });
  });

  // user opens the a dropdown via bootstrap.js: focus mandatory description
  $(document).on('shown.bs.dropdown', dialog, function () {
    $('#lock_description', this).focus();
  });
});
