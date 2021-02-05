// fold empty fieldsets and let users unfold them to reduce clutter
// except for the attributes and command fieldsets (.unfoldable)
// folding is done by hiding (toggle) all children of the fieldset
$(function(){
  $(".collapse_fieldsets fieldset:not(.unfoldable)").each(function(_, fieldset){
    var $fieldset = $(fieldset);

    var filled = $fieldset.find(':input').filter(function(_, el){
      if(el.type == "checkbox" || el.type == "radio") {
        return $(el).is(':checked');
      } else if(el.type == "hidden") {
        return false;
      } else {
        return $(el).val() != "";
      }
    });

    if(filled.length == 0) {
      $fieldset.find('> legend').
        click(function(){ $fieldset.find('> *').not('legend').toggle() }).click().
        css('cursor', 'pointer').
        append(' &#x2304;'); // down caret
    }
  });
});
