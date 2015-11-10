'use strict';

describe("Service: kubernetesService", function() {

  var httpBackend, kubernetesService, httpErrorService, kubernetesRoleFactory;

  var project_id = 'some_project';

  var expected = [
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

  beforeEach(inject(function($httpBackend, _kubernetesService_, _httpErrorService_, _kubernetesRoleFactory_) {
    httpBackend = $httpBackend;
    kubernetesService = _kubernetesService_;
    httpErrorService = _httpErrorService_;
    kubernetesRoleFactory = _kubernetesRoleFactory_;
  }));

  afterEach(function() {
    httpBackend.verifyNoOutstandingExpectation();
    httpBackend.verifyNoOutstandingRequest();
  });

  it('should handle a GET request for loading the kubernetes roles', function() {
    httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles')
      .respond(expected);

    kubernetesService.loadRoles(project_id).then(
      function(data) {
        expect(data).toEqual(expected.map(function(role) {
          return kubernetesRoleFactory.build(role)
        }));
      }
    );
    httpBackend.flush();
  });

  it('should handle a failed GET request for loading the kubernetes roles', function() {
    httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles')
      .respond(500, 'Some error');

    kubernetesService.loadRoles(project_id).then(
      function(result) {
        expect(result.type).toBe('error');
        expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
      }
    );
    httpBackend.flush();
  });

  it('should handle a GET request for loading a kubernetes role', function() {
    var role_id = 0;
    httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/' + role_id)
      .respond(expected[0]);

    kubernetesService.loadRole(project_id, role_id).then(
      function(data) {
        expect(data).toEqual(kubernetesRoleFactory.build(expected[0]));
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

  it('should handle a POST request for updating a kubernetes role', function() {
    var role_id = 0;
    var expected_post_data = JSON.stringify(expected[0], _.without(Object.keys(expected[0]), 'id', 'project_id'));

    httpBackend.expectPUT('/projects/' + project_id + '/kubernetes_roles/' + role_id, expected_post_data)
      .respond(200);

    kubernetesService.updateRole(project_id, expected[0]).then(
      function(data) {
        expect(data).toBe(undefined);
      }
    );
    httpBackend.flush();
  });

  it('should handle a failed POST request for updating a kubernetes role', function() {
    var role_id = 0;
    var expected_post_data = JSON.stringify(expected[0], _.without(Object.keys(expected[0]), 'id', 'project_id'));

    httpBackend.expectPUT('/projects/' + project_id + '/kubernetes_roles/' + role_id, expected_post_data)
      .respond(500, 'Some error');

    kubernetesService.updateRole(project_id, expected[0]).then(
      function(result) {
        expect(result.type).toBe('error');
        expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
      }
    );
    httpBackend.flush();
  });

  it('should handle a failed POST request for updating a kubernetes role', function() {
    var role_id = 0;
    var expected_post_data = JSON.stringify(expected[0], _.without(Object.keys(expected[0]), 'id', 'project_id'));
    var errors = ['Some error'];

    httpBackend.expectPUT('/projects/' + project_id + '/kubernetes_roles/' + role_id, expected_post_data)
      .respond(400, {errors: errors});

    kubernetesService.updateRole(project_id, expected[0]).then(
      function(result) {
        expect(result.type).toBe('error');
        expect(result.messages).toEqual(errors);
      }
    );
    httpBackend.flush();
  });

  it('should handle a GET request for refreshing the kubernetes roles', function() {
    var reference = 'some_reference';

    httpBackend.expectGET('/projects/' + project_id + '/kubernetes_roles/refresh?ref=' + reference)
      .respond(expected);

    kubernetesService.refreshRoles(project_id, reference).then(
      function(data) {
        expect(data).toEqual(expected.map(function(role) {
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
