'use strict';

describe("Controller: ProjectRolesCtrl", function() {

  var scope, controller, element, userProjectRoleFactory, projectRoleFactory, projectRolesService;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($controller, $rootScope, $q, _userProjectRoleFactory_, _projectRoleFactory_, _projectRolesService_) {
    scope = $rootScope.$new();
    userProjectRoleFactory = _userProjectRoleFactory_;
    projectRoleFactory = _projectRoleFactory_;
    projectRolesService = _projectRolesService_;

    element = angular.element('<form data-id="" data-user-id="1" data-user-name="Some user" data-project-id="2" data-project-name="Some project" data-role-id="0"></form>');

    var roles = [{id: 0, display_name: 'Deployer'}, {id: 1, display_name: 'Admin'}];
    var deferred = $q.defer();
    deferred.resolve(roles);
    spyOn(projectRolesService, 'loadProjectRoles').and.returnValue(deferred.promise);

    controller = $controller('ProjectRolesCtrl', {
      $scope: scope,
      $element: element,
      userProjectRoleFactory: userProjectRoleFactory,
      projectRoleFactory: projectRoleFactory,
      projectRolesService: projectRolesService
    });
  }));

  describe('$scope.loadProjectRoles', function() {
    it('should load the results into the scope', function() {
      scope.$digest();

      expect(projectRolesService.loadProjectRoles).toHaveBeenCalled();
      expect(scope.roles[0].id).toBe(0);
      expect(scope.roles[0].display_name).toBe('Deployer');
      expect(scope.roles[1].id).toBe(1);
      expect(scope.roles[1].display_name).toBe('Admin');
    });
  });

  describe("$scope.roleChanged", function() {
    it('should try to create a new project role when the role_id changes and id is undefined', inject(function($q, projectRolesService, messageCenterService) {
      var project_role = userProjectRoleFactory.build(element[0]);

      var deferred = $q.defer();
      deferred.resolve();
      spyOn(projectRolesService, 'createProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      project_role.role_id = 1;
      scope.roleChanged(project_role);
      scope.$digest();

      expect(projectRolesService.createProjectRole).toHaveBeenCalledWith(project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('success', 'User Some user has been granted the role Admin for project Some project');
    }));

    it('should try to update an existing project role when the role_id changes', inject(function($q, projectRolesService, messageCenterService) {
      var project_role = userProjectRoleFactory.build(element[0]);
      project_role.id = 1;

      var deferred = $q.defer();
      deferred.resolve();
      spyOn(projectRolesService, 'updateProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      project_role.role_id = 1;
      scope.roleChanged(project_role);
      scope.$digest();

      expect(projectRolesService.updateProjectRole).toHaveBeenCalledWith(project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('success', 'User Some user has been granted the role Admin for project Some project');
    }));

    it('should display an error message when errors occur while trying to create a new project role', inject(function($q, projectRolesService, messageCenterService) {
      var project_role = userProjectRoleFactory.build(element[0]);

      var deferred = $q.defer();
      deferred.reject();
      spyOn(projectRolesService, 'createProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      project_role.role_id = 1;
      scope.roleChanged(project_role);
      scope.$digest();

      expect(projectRolesService.createProjectRole).toHaveBeenCalledWith(project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('danger', "Failed to assign role 'Admin' to User Some user on project Some project");
    }));

    it('should display an error message when errors occur while trying to update an existing project role', inject(function($q, projectRolesService, messageCenterService) {
      var project_role = userProjectRoleFactory.build(element[0]);
      project_role.id = 1;

      var deferred = $q.defer();
      deferred.reject();
      spyOn(projectRolesService, 'updateProjectRole').and.returnValue(deferred.promise);
      spyOn(messageCenterService, 'add');
      spyOn(messageCenterService, 'markShown');
      spyOn(messageCenterService, 'removeShown');

      project_role.role_id = 1;
      scope.roleChanged(project_role);
      scope.$digest();

      expect(projectRolesService.updateProjectRole).toHaveBeenCalledWith(project_role);
      expect(messageCenterService.markShown).toHaveBeenCalled();
      expect(messageCenterService.removeShown).toHaveBeenCalled();
      expect(messageCenterService.add).toHaveBeenCalledWith('danger', "Failed to assign role 'Admin' to User Some user on project Some project");
    }));
  });

});
