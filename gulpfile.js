var gulp = require('gulp');

// include plug-ins
var gutil = require('gulp-util');
var karma = require('gulp-karma');
var jshint = require('gulp-jshint');

var testFiles = [
  'vendor/assets/javascripts/angular.min.js',
  'vendor/assets/javascripts/angular-mocks.js',
  'vendor/assets/javascripts/underscore.min.js',
  'vendor/assets/javascripts/vis.js',
  'test/angular/test_helper.js',
  'app/assets/javascripts/app.js',
  'app/assets/javascripts/controllers/**/*.js',
  'app/assets/javascripts/directives/**/*.js',
  'app/assets/javascripts/services/**/*.js',
  'app/assets/javascripts/timeline.js',
  'test/angular/**/*_spec.js',
  'plugins/*/test/angular/**/require/*.js',
  'plugins/**/assets/javascripts/**/*.js',
  'plugins/*/test/angular/**/*_spec.js'
];

gulp.task('jshint', function() {
  gulp.src('./app/assets/javascripts/**/*.js')
    .pipe(jshint())
    .pipe(jshint.reporter('default'));
});

gulp.task('test', function() {
  // Be sure to return the stream
  return gulp.src(testFiles)
    .pipe(karma({
      configFile: 'karma.conf.js',
      action: 'run'
    }));
});

gulp.task('default', ['jshint', 'test'], function() {
});
