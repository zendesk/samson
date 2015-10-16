samson.factory('projectRoleFactory', function() {

  function ProjectRole(id, display_name) {
    this.id = id;
    this.display_name = display_name;
  }

  ProjectRole.buildFromJson = function(data) {
    return new ProjectRole(data.id, data.display_name);
  };

  return ProjectRole;
});
