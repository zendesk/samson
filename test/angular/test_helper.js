// Teaspoon includes some support files, but you can use anything from your own support path too.
// require support/jasmine-jquery-1.7.0
// require support/jasmine-jquery-2.0.0
// require support/jasmine-jquery-2.1.0
// require support/sinon
// require support/your-support-file
//
// PhantomJS (Teaspoons default driver) doesn't have support for Function.prototype.bind, which has caused confusion.
// Use this polyfill to avoid the confusion.
//= require support/phantomjs-shims
//= require application
//= require angular-mocks/angular-mocks

// angular-rails-templates.coffee Mock
// Dummy mock for running Karma and seeing Angular Rails Templates
// See: https://github.com/pitr/angular-rails-templates/issues/63
angular.module("templates", []);


// Disable the SSE streaming, since it leaves connections open tests can't be re-run.
samson.factory('SseFactory', function() {
  return {
    on: function() {}
  };
});
