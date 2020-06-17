// make textareas expand to their contents size
// adjusting the math (+3) to make 1-line have regular size
$(function(){
  $('textarea:visible').each(function(i, element){
    element.style.height = element.scrollHeight + 3 +"px";
  });
});
