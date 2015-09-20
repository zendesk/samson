samson.service('projectRolesService', function ($http) {

    this.loadProjectRoles = function () {
        return $http.get('/admin/project_roles');
    };

    this.createProjectRole = function (project_role, new_role_id) {
        var data = {
            user_id: project_role.user_id,
            project_id: project_role.project_id,
            role_id: new_role_id
        };

        return $http.post('/admin/users/' + project_role.user_id + '/user_projects_roles', {project_role: data});
    };

    this.updateProjectRole = function (project_role, new_role_id) {
        var data = {
            role_id: new_role_id
        };

        return $http.put('/admin/users/' + project_role.user_id + '/user_projects_roles/' + project_role.id, { project_role: data });
    };
});