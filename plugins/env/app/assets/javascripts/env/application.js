$(function(){
  $(".duplicate_previous_row").click(function(e){
    e.preventDefault();
    var $row = $(this).prev();
    var $new_row = $row.clone();
    $new_row.find(':input').val('');

    // each row needs a new unique name and id to make rails do the update logic correctly for environment_variables
    $new_row.find(':input').each(function(i, input){
      var $input = $(input);
      $.each(['id', 'name'], function(i, attr){
        $input.attr(attr, $input.attr(attr).replace(/\d+/, function(n){ return ++n; }));
      });
    });

    $row.after($new_row);
  });
});
