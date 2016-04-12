// show errors immediately so we can catch them early and fix
$(function(){
  if($('meta[name=environment]').first().attr('content') == "development") {
    window.onerror = function(msg, url, line, col, error) {
      var extra = !col ? '' : '\ncolumn: ' + col;
      extra += !error ? '' : '\nerror: ' + error;
      alert("Error: " + msg + "\nurl: " + url + "\nline: " + line + extra);
    };
  }
});
