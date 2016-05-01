// setting a cookie with the user's timezone in it to use on the rails side of things
var tz = jstz.determine();
$.cookie("timezone", tz.name(), {path: "/"});

