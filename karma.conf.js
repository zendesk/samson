// Karma configuration
// Generated on Thu Feb 06 2014 10:52:08 GMT+1100 (EST)

module.exports = function(config) {
  config.set({

    // base path, that will be used to resolve files and exclude
    basePath: '.',


    // frameworks to use
    frameworks: ['jasmine'],


    // list of files / patterns to load in the browser
    files: [
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
    ],


    // list of files to exclude
    exclude: [

    ],


    // test results reporter to use
    // possible values: 'dots', 'progress', 'junit', 'growl', 'coverage'
    reporters: ['progress'],


    // web server port
    port: 9876,


    // enable / disable colors in the output (reporters and logs)
    colors: true,


    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,


    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,


    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera (has to be installed with `npm install karma-opera-launcher`)
    // - Safari (only Mac; has to be installed with `npm install karma-safari-launcher`)
    // - PhantomJS
    // - IE (only Windows; has to be installed with `npm install karma-ie-launcher`)
    browsers: ['PhantomJS'],


    // If browser does not capture in given timeout [ms], kill it
    captureTimeout: 60000,


    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: false
  });
};
