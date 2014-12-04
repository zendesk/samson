var gulp = require('gulp');

// include plug-ins
var gutil = require('gulp-util');
var jshint = require('gulp-jshint');
var karma = require('karma').server;

gulp.task('jshint', function() {
  gulp.src('./app/assets/javascripts/*.js')
    .pipe(jshint())
    .pipe(jshint.reporter('default'));
});

gulp.task('test', function(done) {
  karma.start({
    configFile: __dirname + '/karma.conf.js',
    singleRun: true
  }, done);
});

gulp.task('default', ['jshint', 'test'], function() {
});
