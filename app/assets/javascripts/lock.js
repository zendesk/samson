$(function () {
  $('.datetimepicker').datetimepicker();

  $('.new-lock-form').submit(function (e) {
    var lockDeleteAtInput = $(e.target).find('#lock_delete_at');
    var lockDeleteAtVal = lockDeleteAtInput.val();

    if (lockDeleteAtVal !== '') {
      var lockExpireMoment = moment(lockDeleteAtVal);

      lockDeleteAtInput.val(moment(lockDeleteAtVal).utc().format());
    }
  });
});
