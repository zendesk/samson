'use strict';

describe("Service: kubernetesService", function() {

  var httpBackend, kubernetesService, httpErrorService, kubernetesRoleFactory, kubernetesReleaseFactory;

  var project_id = 'some_project';

  var roles = [
    {
      id: 0,
      project_id: 1,
      name: 'some_role_name',
      config_file: 'some_config_file',
      replicas: 1,
      cpu: 0.2,
      ram: 512,
      service_name: 'some_service_name',
      deploy_strategy: 'some_deploy_strategy'
    },
    {
      id: 1,
      project_id: 1,
      name: 'another_role_name',
      config_file: 'another_config_file',
      replicas: 1,
      cpu: 0.2,
      ram: 512,
      service_name: 'another_service_name',
      deploy_strategy: 'another_deploy_strategy'
    }
  ];

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($httpBackend, _kubernetesService_, _httpErrorService_, _kubernetesRoleFactory_, _kubernetesReleaseFactory_) {
    httpBackend = $httpBackend;
    kubernetesService = _kubernetesService_;
    httpErrorService = _httpErrorService_;
    kubernetesRoleFactory = _kubernetesRoleFactory_;
    kubernetesReleaseFactory = _kubernetesReleaseFactory_;
  }));

  afterEach(function() {
    httpBackend.verifyNoOutstandingExpectation();
    httpBackend.verifyNoOutstandingRequest();
  });

  describe('#loadRoles', function() {
    it('should handle a GET request for loading the kubernetes roles', function() {
      httpBackend.expectGET('/projects/' + project_id + '/kubernetes/roles')
        .respond(roles);

      kubernetesService.loadRoles(project_id).then(
        function(data) {
          expect(data).toEqual(roles.map(kubernetesRoleFactory.build));
        }
      );
      httpBackend.flush();
    });

    it('should handle a failed GET request for loading the kubernetes roles', function() {
      httpBackend.expectGET('/projects/' + project_id + '/kubernetes/roles')
        .respond(500, 'Some error');

      kubernetesService.loadRoles(project_id).then(
        function(result) {
          expect(result.type).toBe('error');
          expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
        }
      );
      httpBackend.flush();
    });
  });

  describe('#loadRole', function() {
    it('should handle a GET request for loading a kubernetes role', function() {
      var role_id = 0;
      httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/' + role_id)
        .respond(roles[0]);

      kubernetesService.loadRole(project_id, role_id).then(
        function(data) {
          expect(data).toEqual(kubernetesRoleFactory.build(roles[0]));
        }
      );
      httpBackend.flush();
    });

    it('should handle a failed GET request for loading a kubernetes role', function() {
      var role_id = 0;
      httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/' + role_id)
        .respond(500, 'Some error');

      kubernetesService.loadRole(project_id, role_id).then(
        function(result) {
          expect(result.type).toBe('error');
          expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
        }
      );
      httpBackend.flush();
    });
  });

  describe('#updateRole', function() {
    it('should handle a PUT request for updating a kubernetes role', function() {
      var role_id = 0;
      var expected_post_data = JSON.stringify(roles[0], _.without(Object.keys(roles[0]), 'id', 'project_id'));

      httpBackend.expectPUT('/projects/' + project_id + '/kubernetes_roles/' + role_id, expected_post_data)
        .respond(200);

      kubernetesService.updateRole(project_id, roles[0]).then(
        function(data) {
          expect(data).toBe(undefined);
        }
      );
      httpBackend.flush();
    });

    it('should handle a failed PUT request for updating a kubernetes role', function() {
      var role_id = 0;
      var expected_post_data = JSON.stringify(roles[0], _.without(Object.keys(roles[0]), 'id', 'project_id'));

      httpBackend.expectPUT('/projects/' + project_id + '/kubernetes_roles/' + role_id, expected_post_data)
        .respond(500, 'Some error');

      kubernetesService.updateRole(project_id, roles[0]).then(
        function(result) {
          expect(result.type).toBe('error');
          expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
        }
      );
      httpBackend.flush();
    });

    it('should handle a failed PUT request for updating a kubernetes role', function() {
      var role_id = 0;
      var expected_post_data = JSON.stringify(roles[0], _.without(Object.keys(roles[0]), 'id', 'project_id'));
      var errors = ['Some error'];

      httpBackend.expectPUT('/projects/' + project_id + '/kubernetes_roles/' + role_id, expected_post_data)
        .respond(400, {errors: errors});

      kubernetesService.updateRole(project_id, roles[0]).then(
        function(result) {
          expect(result.type).toBe('error');
          expect(result.messages).toEqual(errors);
        }
      );
      httpBackend.flush();
    });
  });

  describe('#refreshRoles', function() {
    it('should handle a GET request for refreshing the kubernetes roles', function() {
      var reference = 'some_reference';

      httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/refresh?ref=' + reference)
        .respond(roles);

      kubernetesService.refreshRoles(project_id, reference).then(
        function(data) {
          expect(data).toEqual(roles.map(function(role) {
            return kubernetesRoleFactory.build(role)
          }));
        }
      );
      httpBackend.flush();
    });

    it('should handle a failed GET request for refreshing the kubernetes roles', function() {
      var reference = 'some_reference';

      httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/refresh?ref=' + reference)
        .respond(500, 'Some error');

      kubernetesService.refreshRoles(project_id, reference).then(
        function(result) {
          expect(result.type).toBe('error');
          expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
        }
      );
      httpBackend.flush();
    });

    it('should handle a 404 on a GET request for refreshing the kubernetes roles', function() {
      var reference = 'some_reference';

      httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/refresh?ref=' + reference)
        .respond(404, 'Not found');

      kubernetesService.refreshRoles(project_id, reference).then(
        function(result) {
          expect(result.type).toBe('warning');
          expect(result.messages).toEqual(['No roles have been found for the given Git reference.']);
        }
      );
      httpBackend.flush();
    });
  });

  describe('#createRelease', function() {
    var build_id = 1;
    var deploy_groups = [
      {
        id: 1,
        roles: roles
      }
    ];

    function deployGroupMapper(deploy_group) {
      return {
        id: deploy_group.id,
        roles: deploy_group.roles.map(roleMapper)
      };
    }

    function roleMapper(role) {
      return _.pick(role, 'id', 'replicas');
    }

    it('should handle a POST request for creating a kubernetes release', function() {
      var expected_payload = {
        build_id: build_id,
        deploy_groups: deploy_groups.map(deployGroupMapper)
      };

      var expected_response = {
        id: 0,
        build_id: build_id,
        deploy_groups: deploy_groups
      };

      httpBackend.expectPOST('/projects/' + project_id + '/kubernetes_releases', expected_payload)
        .respond(200, expected_response);

      kubernetesService.createRelease(project_id, build_id, deploy_groups).then(
        function(data) {
          expect(data).toEqual(expected_response);
        }
      );
      httpBackend.flush();
    });
  });

  describe('#loadKubernetesReleases', function() {
    var releases = [
      {
        id: 0,
        created_at: 'some_date',
        user: {
          name: 'some_user'
        },
        build: {
          id: 1,
          label: 'some_build'
        },
        deploy_groups: [
          {
            id: 0,
            name: 'a_deploy_group'
          },
          {
            id: 1,
            name: 'another_deploy_group'
          }
        ]
      }
    ];

    it('should handle a GET request for loading the kubernetes releases', function() {
      httpBackend.expectGET('/projects/' + project_id + '/kubernetes_releases')
        .respond(releases);

      kubernetesService.loadKubernetesReleases(project_id).then(
        function(data) {
          expect(data).toEqual(releases.map(kubernetesReleaseFactory.build));
        }
      );
      httpBackend.flush();
    });
  });
});
