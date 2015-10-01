'use strict';

describe("Factory: userProjectRoleFactory", function() {

  var userProjectRoleFactory;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_userProjectRoleFactory_) {
    userProjectRoleFactory = _userProjectRoleFactory_;
  }));

  it('should create a new object from the given DOM element', function() {
    var element = angular.element('<form data-id="" data-user-id="1" data-user-name="Some user" data-project-id="2" data-project-name="Some project" data-role-id="0"></form>');

    var project_role = userProjectRoleFactory.build(element[0]);
    expect(project_role.id).toBe(undefined);
    expect(project_role.user_id).toBe(1);
    expect(project_role.project_id).toBe(2);
    expect(project_role.role_id).toBe(0);
    expect(project_role.user_name).toBe("Some user");
    expect(project_role.project_name).toBe("Some project");

    element = angular.element('<form data-id="3" data-user-id="1" data-user-name="Some user" data-project-id="2" data-project-name="Some project" data-role-id="0"></form>');

    project_role = userProjectRoleFactory.build(element[0]);
    expect(project_role.id).toBe(3);
    expect(project_role.user_id).toBe(1);
    expect(project_role.project_id).toBe(2);
    expect(project_role.role_id).toBe(0);
    expect(project_role.user_name).toBe("Some user");
    expect(project_role.project_name).toBe("Some project");
  });
});
