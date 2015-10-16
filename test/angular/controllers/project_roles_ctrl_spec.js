'use strict';

describe("Controller: ProjectRolesCtrl", function() {

  var scope, controller, element, userProjectRoleFactory, projectRoleFactory;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($controller, $rootScope, _userProjectRoleFactory_, _projectRoleFactory_) {
    scope = $rootScope.$new();
    userProjectRoleFactory = _userProjectRoleFactory_;
    projectRoleFactory = _projectRoleFactory_;

    element = angular.element('<form data-id="" data-user-id="1" data-user-name="Some user" data-project-id="2" data-project-name="Some project" data-role-id="0"></form>');

    controller = $controller('ProjectRolesCtrl', {
      $scope: scope,
      $element: element,
      userProjectRoleFactory: userProjectRoleFactory,
      projectRoleFactory: projectRoleFactory
    });
  }));

  describe('$scope.initModel', function() {

    it('should read the data attributes from current element into the scope', function() {
      scope.initModel();
      expect(scope.project_role.id).toBe(undefined);
      expect(scope.project_role.user_id).toBe(1);
      expect(scope.project_role.project_id).toBe(2);
      expect(scope.project_role.role_id).toBe(0);
      expect(scope.project_role.project_name).toBe("Some project");
      expect(scope.project_role.user_name).toBe("Some user");
    });

    it('should invoke loadProjectRoles and load the results into the scope', inject(function($q, projectRolesService) {
      var expected = {data: [{id: 0, display_name: 'Deployer'}, {id: 1, display_name: 'Admin'}]};

      var deferred = $q.defer();
      deferred.resolve(expected);
      spyOn(projectRolesService, 'loadProjectRoles').and.returnValue(deferred.promise);

      scope.initModel();

      scope.$digest();

      expect(projectRolesService.loadProjectRoles).toHaveBeenCalled();
      expect(scope.roles[0].id).toBe(0);
      expect(scope.roles[0].display_name).toBe('Deployer');
      expect(scope.roles[1].id).toBe(1);
      expect(scope.roles[1].display_name).toBe('Admin');
    }));
  });

  describe("$watch('project_role.role_id')", function() {

    beforeEach(function() {
      scope.project_role = userProjectRoleFactory.build(element[0]);
      scope.roles = [
        projectRoleFactory.buildFromJson({id: 0, display_name: 'Deployer'}),
        projectRoleFactory.buildFromJson({id: 1, display_name: 'Admin'})
      ];
      //scope.$digest();
    });

    it('should try to create a new project role when the role_id changes and id is undefined', inject(function($q, projectRolesService, messageCenterService) {
      var deferred = $q.defer();
      deferred.resolve();
      spyOn(projectRolesService, 'createProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      scope.project_role.role_id = 1;
      scope.roleChanged();
      scope.$digest();

      expect(projectRolesService.createProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('success', 'User Some user has been granted the role Admin for project Some project');
    }));

    it('should try to update an existing project role when the role_id changes', inject(function($q, projectRolesService, messageCenterService) {
      scope.project_role.id = 1;

      var deferred = $q.defer();
      deferred.resolve();
      spyOn(projectRolesService, 'updateProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      scope.project_role.role_id = 1;
      scope.roleChanged();
      scope.$digest();

      expect(projectRolesService.updateProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('success', 'User Some user has been granted the role Admin for project Some project');
    }));

    it('should display an error message when errors occur while trying to create a new project role', inject(function($q, projectRolesService, messageCenterService) {
      var deferred = $q.defer();
      deferred.reject();
      spyOn(projectRolesService, 'createProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      scope.project_role.role_id = 1;
      scope.roleChanged();
      scope.$digest();

      expect(projectRolesService.createProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('danger', "Failed to assign role 'Admin' to User Some user on project Some project");
    }));

    it('should display an error message when errors occur while trying to update an existing project role', inject(function($q, projectRolesService, messageCenterService) {
      scope.project_role.id = 1;

      var deferred = $q.defer();
      deferred.reject();
      spyOn(projectRolesService, 'updateProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      scope.project_role.role_id = 1;
      scope.roleChanged();
      scope.$digest();

      expect(projectRolesService.updateProjectRole).toHaveBeenCalledWith(scope.project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('danger', "Failed to assign role 'Admin' to User Some user on project Some project");
    }));
  });
});
