module.exports = function(config) {
  config.set({
    basePath: '.',
    preprocessors: {
      '**/*.coffee': 'coffee',
    },
    frameworks: [
      'sprockets-mincer',
      'jasmine'
    ],
    sprocketsPaths: [
      'app/assets/javascripts',
      'vendor/assets/javascripts',
      'test/angular'
    ],
    sprocketsBundles: [
      'application.js',
      'spec_helper.js'
    ],
    rubygems: {
      "bootstrap-sass": ["assets/javascripts"],
      "jquery-rails": ["vendor/assets/javascripts"],
      "jquery-ui-rails": ["app/assets/javascripts"],
      "bootstrap-x-editable-rails": ["app/assets/javascripts"],
      "angularjs-rails": ["vendor/assets/javascripts"],
      "momentjs-rails": ["vendor/assets/javascripts"],
      "rickshaw_rails": ["app/assets/javascripts"]
    },
    files: [
      'test/angular/*_spec.js'
    ],
    browsers: ['PhantomJS']
  });
};
