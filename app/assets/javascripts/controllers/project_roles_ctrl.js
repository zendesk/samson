samson.controller('ProjectRolesCtrl', function ($scope, $element, $filter, $http, $q, projectRolesService, messageCenterService) {
    $scope.project_role = {};
    $scope.role_name = '';
    $scope.roles = [];

    $scope.initModel = function () {
        var toggle = $element[0].querySelector('a');

        $scope.project_role = {
            id: toggle.getAttribute('data-id'),
            user_id: toggle.getAttribute('data-user-id'),
            project_id: toggle.getAttribute('data-project-id'),
            role_id: toggle.getAttribute('data-role-id')
        };

        loadProjectRoles();
    };

    $scope.submit = function (data) {
        if ($scope.project_role.id.length) {
            return updateProjectRole($scope.project_role, data);
        }
        else {
            return createProjectRole($scope.project_role, data);
        }
    };

    $scope.$watch('roles', function (newValue, oldValue) {
        if (newValue !== oldValue) {
            updateRoleName();
        }
    });

    $scope.$watch('project_role.role_id', function (newValue, oldValue) {
        if (newValue !== oldValue) {
            updateRoleName();
        }
    });

    function loadProjectRoles() {
        projectRolesService.loadProjectRoles().then(
            function (response) {
                $scope.roles = response.data;
            }
        );
    }

    function scopeHasRoles() {
        return $scope.roles && $scope.roles.length;
    }

    function scopeHasProjectRole() {
        return $scope.project_role && $scope.project_role.role_id && $scope.project_role.role_id.length;
    }

    function roleNameFor(role_id) {
        var filtered = $filter('filter')($scope.roles, {id: role_id});
        return filtered ? filtered[0].display_name : '';
    }

    function updateRoleName() {
        if (scopeHasRoles() && scopeHasProjectRole()) {
            $scope.role_name = roleNameFor($scope.project_role.role_id);
        }
    }

    function setProjectRole(project_role) {
        $scope.project_role.id = project_role.id.toString();
    }

    function createProjectRole(project_role, new_role_id) {
        var d = $q.defer();
        projectRolesService.createProjectRole(project_role, new_role_id).then(
            function (response) {
                var message = 'User has been granted the role ' + roleNameFor(new_role_id) + ' for project ID: ' + project_role.project_id;
                showSuccessMessage(message);
                setProjectRole(response.data.project_role);
                d.resolve();
            },
            function (response) {
                showErrorMessage(response.data);
                //needs to reject promise with a string to force error handling
                //however, error is reported by message service instead of being displayed next to the field
                d.reject("");
            }
        );
        return d.promise;
    }

    function updateProjectRole(project_role, new_role_id) {
        var d = $q.defer();
        projectRolesService.updateProjectRole(project_role, new_role_id).then(
            function (response) {
                var message = 'User has been granted the role ' + roleNameFor(new_role_id) + ' for project ID: ' + project_role.project_id;
                showSuccessMessage(message);
                d.resolve();
            },
            function (response) {
                showErrorMessage(response.data);
                //needs to reject promise with a string to force error handling
                //however, error is reported by message service instead of being displayed next to the field
                d.reject("");
            }
        );
        return d.promise;
    }

    function showSuccessMessage(message) {
        messageCenterService.add('success', message);
    }

    function showErrorMessage(message) {
        messageCenterService.add('danger', message);
    }
});