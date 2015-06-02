$(function(){
  $(".duplicate_previous_row").click(function(e){
    e.preventDefault();
    var $row = $(this).prev();
    var $new_row = $row.clone();
    $new_row.find('input').val('');
    $row.after($new_row);
  });
});
