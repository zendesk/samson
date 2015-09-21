'use strict';

describe("Controller: ProjectRolesCtrl", function() {

  var scope, controller;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($controller, $rootScope) {
    scope = $rootScope.$new();

    var element = angular.element('<form data-id="" data-user-id="1" data-user-name="Some user" data-project-id="2" data-project-name="Some project" data-role-id="0"></form>');

    controller = $controller('ProjectRolesCtrl', {
      $scope: scope,
      $element: element
    });
  }));

  describe('$scope.initModel', function() {

    it('should read the data attributes from current element into the scope', function() {
      var expected = {id: undefined, user_id: 1, project_id: 2, role_id: 0};
      scope.initModel();
      expect(expected).toEqual(scope.project_role);
    });

    it('should invoke loadProjectRoles and load the results into the scope', inject(function($q, projectRolesService) {
      var expected = {data: [{id: 0, display_name: 'Deployer'}, {id: 1, display_name: 'Admin'}]};

      var deferred = $q.defer();
      deferred.resolve(expected);
      spyOn(projectRolesService, 'loadProjectRoles').and.returnValue(deferred.promise);

      scope.initModel();

      scope.$digest();

      expect(projectRolesService.loadProjectRoles).toHaveBeenCalled();
      expect(scope.roles).toEqual(expected.data);
    }));
  });

  describe("$watch('project_role.role_id')", function() {

    beforeEach(function() {
      scope.project_role = {id: undefined, user_id: 1, project_id: 1, role_id: 0};
      scope.roles = [{id: 0, display_name: 'Deployer'}, {id: 1, display_name: 'Admin'}];
      scope.$digest();
    });

    it('should try to create a new project role when the role_id changes and id is undefined', inject(function($q, projectRolesService, messageCenterService) {
      var expected = {data: {project_role: {id: 0, user_id: 1, project_id: 1, role_id: 1}}};

      var deferred = $q.defer();
      deferred.resolve(expected);
      spyOn(projectRolesService, 'createProjectRole').and.returnValue(deferred.promise);

      spyOn(messageCenterService, 'add');

      scope.project_role.role_id = 1;
      scope.$digest();

      expect(projectRolesService.createProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.add).toHaveBeenCalledWith('success', 'User Some user has been granted the role Admin for project Some project');
      expect(scope.project_role.id).toEqual(expected.data.project_role.id);
    }));

    it('should try to update an existing project role when the role_id changes', inject(function($q, projectRolesService, messageCenterService) {
      scope.project_role.id = 1;

      var expected = {data: {project_role: {id: 1, user_id: 1, project_id: 1, role_id: 1}}};

      var deferred = $q.defer();
      deferred.resolve(expected);
      spyOn(projectRolesService, 'updateProjectRole').and.returnValue(deferred.promise);

      spyOn(messageCenterService, 'add');

      scope.project_role.role_id = 1;
      scope.$digest();

      expect(projectRolesService.updateProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.add).toHaveBeenCalledWith('success', 'User Some user has been granted the role Admin for project Some project');
      expect(scope.project_role.id).toEqual(expected.data.project_role.id);
    }));

    it('should display an error message when errors occur while trying to create a new project role', inject(function($q, projectRolesService, messageCenterService) {
      var deferred = $q.defer();
      deferred.reject();
      spyOn(projectRolesService, 'createProjectRole').and.returnValue(deferred.promise);

      spyOn(messageCenterService, 'add');

      scope.project_role.role_id = 1;
      scope.$digest();

      expect(projectRolesService.createProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.add).toHaveBeenCalledWith('danger', "Failed to assign role 'Admin' to User Some user on project Some project");
    }));

    it('should display an error message when errors occur while trying to update an existing project role', inject(function($q, projectRolesService, messageCenterService) {
      scope.project_role.id = 1;

      var deferred = $q.defer();
      deferred.reject();
      spyOn(projectRolesService, 'updateProjectRole').and.returnValue(deferred.promise);

      spyOn(messageCenterService, 'add');

      scope.project_role.role_id = 1;
      scope.$digest();

      expect(projectRolesService.updateProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.add).toHaveBeenCalledWith('danger', "Failed to assign role 'Admin' to User Some user on project Some project");
    }));
  });
});
