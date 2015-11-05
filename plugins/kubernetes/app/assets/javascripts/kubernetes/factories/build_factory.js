samson.factory('buildFactory', function() {

  function Build(id, label) {
    this.id = id;
    this.label = label;
  }

  Build.build = function(data) {
    return new Build(
      data.id,
      data.label
    );
  };

  return Build;
});
