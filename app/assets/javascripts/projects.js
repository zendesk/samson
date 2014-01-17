$(function() {

  var maxHeight = 0,
      $projectTiles = $('.project-tile');

  $projectTiles.each(function(){
    var tileHeight = $(this).height();
    if (maxHeight < tileHeight) {
      maxHeight = tileHeight;
    }
  });

  $projectTiles.height(maxHeight);

});
