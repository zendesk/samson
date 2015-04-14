var gulp = require('gulp');

// include plug-ins
var jshint = require('gulp-jshint');

gulp.task('jshint', function() {
  return gulp.src('./app/assets/javascripts/**/*.js')
    .pipe(jshint())
    .pipe(jshint.reporter('default'))
    .pipe(jshint.reporter('fail'));
});

gulp.task('default', ['jshint'], function() {
});
