//Underscore mixins used across the javascript code
_.mixin({

  /*
   Utility function to check if the object is undefined or empty
   */
  isUndefinedOrEmpty: function(object) {
    return _.isUndefined(object) || _.isEmpty(object);
  },

  /*
   Utility function to check if the object is not undefined nor empty
   */
  isNotUndefinedOrEmpty: function(object) {
    return !_.isUndefinedOrEmpty(object);
  },

  /*
   Checks if the object has been defined
   */
  isDefined: function(object) {
    return !_.isUndefined(object);
  },

  /*
   Returns a new instance of the array with shallow-copied versions of it's objects.
   See http://underscorejs.org/#clone for more information.
   */
  cloneArray: function(arr) {
    return _.map(arr, _.clone);
  }
});
