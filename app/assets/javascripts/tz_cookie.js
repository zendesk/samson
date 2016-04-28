var tz = jstz.determine();
$.cookie("timezone", tz.name(), {path: "/"});

