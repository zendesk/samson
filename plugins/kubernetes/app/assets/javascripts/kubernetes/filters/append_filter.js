samson.filter('append', function(){

  return function(input, str) {
    return _.isNotUndefinedOrEmpty(input) ? input + str : input;
  };

});
