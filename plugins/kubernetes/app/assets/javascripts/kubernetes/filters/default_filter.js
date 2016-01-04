samson.filter('default', function() {

  return function(input, str) {
    return _.isUndefinedOrEmpty(input) ? str : input;
  };

});
