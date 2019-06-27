// load part of the nvigation only if the user unfolds it
//   <a class="lazy-load-nav"
//   <ul class="dropdown-menu"
//     <li class="lazy-load-nav--placeholder"
$(document).one('click', 'a.lazy-load-nav', function() {
  var $placeholder = $(this).parent().find("li.lazy-load-nav--placeholder");
  $placeholder.responsiveLoad(null, function(content){
    $placeholder.replaceWith(content);
  });
});
