var gulp = require('gulp');

// include plug-ins
var gutil = require('gulp-util');
var karma = require('gulp-karma');
var jshint = require('gulp-jshint');

var sourceAssets = [
  'vendor/assets/javascripts/angular.min.js',
  'vendor/assets/javascripts/angular-mocks.js',
  'vendor/assets/javascripts/underscore-min.js',
  'vendor/assets/javascripts/jquery.min.js',
  'vendor/assets/javascripts/jquery_mentions_input/jquery.mentionsInput.js',
  'app/assets/javascripts/app.js',
  'app/assets/javascripts/timeline.js',
  'app/assets/javascripts/directives/buddy_request_box.js',
  'test/angular/angular-rails-templates.js',
  'test/angular/*_spec.js'
];

gulp.task('jshint', function() {
  gulp.src('./app/assets/javascripts/*.js')
    .pipe(jshint())
    .pipe(jshint.reporter('default'));
});

gulp.task('test', function() {
  // Be sure to return the stream
  return gulp.src(sourceAssets)
    .pipe(karma({
      configFile: 'karma.conf.js',
      action: 'run'
    }));
});

gulp.task('default', ['jshint', 'test'], function() {
});
