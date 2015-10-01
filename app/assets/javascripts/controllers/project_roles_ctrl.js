samson.controller('ProjectRolesCtrl', function ($scope, $element, $filter, projectRolesService, messageCenterService) {
    $scope.project_role = {};
    $scope.roles = [];

    $scope.initModel = function () {
        $scope.project_role = {
            id: getUniqueId(),
            user_id: getUserId(),
            project_id: getProjectId(),
            role_id: getRoleId()
        };

        loadProjectRoles();
    };

    $scope.$watch('project_role.role_id', function (new_role_value, old_role_value) {
        if (new_role_value !== old_role_value) {
            if (exists($scope.project_role)) {
                return updateProjectRole($scope.project_role, new_role_value);
            }
            else {
                return createProjectRole($scope.project_role, new_role_value);
            }
        }
    });

    function loadProjectRoles() {
        projectRolesService.loadProjectRoles().then(
            function (response) {
                $scope.roles = response.data;
            }
        );
    }

    function exists(project_role) {
        return project_role.id;
    }

    function createProjectRole(project_role) {
        projectRolesService.createProjectRole(project_role).then(
            function (response) {
                var message = 'User ' + getUserName() + ' has been granted the role ' + roleNameFor(project_role.role_id) + ' for project ' + getProjectName();
                showSuccessMessage(message);
                project_role.id = response.data.project_role.id;
            },
            function () {
                var message = "Failed to assign role '" + roleNameFor(project_role.role_id) + "' to User " + getUserName() + " on project " + getProjectName();
                showErrorMessage(message);
            }
        );
    }

    function updateProjectRole(project_role) {
        projectRolesService.updateProjectRole(project_role).then(
            function () {
                var message = 'User ' + getUserName() + ' has been granted the role ' + roleNameFor(project_role.role_id) + ' for project ' + getProjectName();
                showSuccessMessage(message);
            },
            function () {
                var message = "Failed to assign role '" + roleNameFor(project_role.role_id) + "' to User " + getUserName() + " on project " + getProjectName();
                showErrorMessage(message);
            }
        );
    }

    function getUniqueId()
    {
        return getAttributeAsInt('data-id');
    }

    function getUserId()
    {
        return getAttributeAsInt('data-user-id');
    }

    function getUserName()
    {
        return getAttributeAsString('data-user-name');
    }

    function getProjectId()
    {
        return getAttributeAsInt('data-project-id');
    }

    function getProjectName()
    {
        return getAttributeAsString('data-project-name');
    }

    function getRoleId()
    {
        return getAttributeAsInt('data-role-id');
    }

    function getAttributeAsInt(attr_name) {
        var attr = getAttribute(attr_name);
        return attr.length ? parseInt(attr) : undefined;
    }

    function getAttributeAsString(attr_name) {
        var attr = getAttribute(attr_name);
        return attr.length ? attr : undefined;
    }

    function getAttribute(attr_name) {
        return getElement().getAttribute(attr_name);
    }

    function getElement() {
        return $element[0];
    }

    function roleNameFor(role_id) {
        var filtered = $filter('filter')($scope.roles, {id: role_id});
        return filtered ? filtered[0].display_name : '';
    }

    function showSuccessMessage(message) {
        messageCenterService.add('success', message);
    }

    function showErrorMessage(message) {
        messageCenterService.add('danger', message);
    }
});