'use strict';

describe("Service: projectRolesService", function() {

  var projectRolesService, httpBackend;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_projectRolesService_, $httpBackend) {
    projectRolesService = _projectRolesService_;
    httpBackend = $httpBackend;
  }));

  afterEach(function() {
    httpBackend.verifyNoOutstandingExpectation();
    httpBackend.verifyNoOutstandingRequest();
    //httpBackend.resetExpectations();
  });


  it('should handle GET request for loading the project roles catalog', function() {
    var expected = [{id: 0, display_name: 'Deployer'}, {id: 1, display_name: 'Admin'}];

    httpBackend.expectGET('/project_roles').respond(expected);

    projectRolesService.loadProjectRoles().then(function(response) {
      expect(response.data).toEqual(expected)
    });

    httpBackend.flush();
  });

  it('should handle POST requests for creating a new project role', function() {
    var user_id = 1;
    var project_id = 2;
    var role_id = 0;

    var project_role = {user_id: user_id, project_id: project_id, role_id: role_id};
    var post_data = {project_role: project_role};
    var expected_response = {id: 0, user_id: user_id, project_id: project_id, role_id: role_id};

    //id should not be sent to the backend, as it should be generated
    httpBackend.expectPOST('/projects/' + project_role.project_id + '/project_roles', post_data)
      .respond(expected_response);

    projectRolesService.createProjectRole(project_role).then(function(response) {
      expect(response.data).toEqual(expected_response)
    });

    httpBackend.flush();
  });

  it('should handle PUT requests to update an existing project role', function() {
    var id = 0;
    var user_id = 1;
    var project_id = 2;
    var role_id = 0;

    var project_role = {id: id, user_id: user_id, project_id: project_id, role_id: role_id};
    var post_data = {project_role: {role_id: project_role.role_id}};
    var expected_response = {id: id, user_id: user_id, project_id: project_id, role_id: role_id};

    //id should not be sent to the backend, as it should be generated
    httpBackend.expectPUT('/projects/' + project_role.project_id + '/project_roles/' + project_role.id, post_data)
      .respond(expected_response);

    projectRolesService.updateProjectRole(project_role).then(function(response) {
      expect(response.data).toEqual(expected_response)
    });

    httpBackend.flush();
  });
});
