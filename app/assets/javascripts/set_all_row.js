// when user changes an input in the all row, make the same change to all sibling rows
$(document).on('change', 'tr.set-all-row input', function(){
  var input = $(this);
  var row = $(this).parent().parent();

  var index = row.find('input').index(input);
  var sibling_inputs = $(row.siblings().map(function(_, row){
    return $(row).find('input').get(index);
  }));

  if(input.is(':checkbox')) {
    sibling_inputs.prop('checked', input.prop('checked'));
  } else {
    sibling_inputs.val(input.val());
  }
});
