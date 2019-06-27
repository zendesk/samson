// make the user type the param of the resource to be deleted to make sure they pay attention
$(function(){
  $("a[data-type-to-delete]").click(function(e){
    var message = $(this).data("type-to-delete");
    var parts = $(this).attr("href").split("/");
    var text = parts[parts.length - 1];
    var answer = prompt(message + " Type '" + text + "'");
    if(answer != text) {
      e.preventDefault();
      e.stopPropagation();
    }
  })
});
