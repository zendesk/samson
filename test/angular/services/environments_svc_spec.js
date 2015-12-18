'use strict';

describe("Service: environmentsService", function() {

  var environmentsService, httpBackend, httpErrorService;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_environmentsService_, $httpBackend, _httpErrorService_) {
    environmentsService = _environmentsService_;
    httpBackend = $httpBackend;
    httpErrorService = _httpErrorService_;
  }));

  afterEach(function() {
    httpBackend.verifyNoOutstandingExpectation();
    httpBackend.verifyNoOutstandingRequest();
  });


  it('should handle GET request for loading the environments', function() {
    var response = {
        environments: [
          {id: 0, name: 'an environment'},
          {id: 1, name: 'another environment'}
        ]
    };

    httpBackend.expectGET('/admin/environments').respond(response);

    environmentsService.loadEnvironments().then(function(environments) {
      expect(environments).toEqual(response.environments)
    });

    httpBackend.flush();
  });

  it('should handle GET request with a response error', function() {
    var errors = {
        errors: ['a message', 'another message']
    };

    httpBackend.expectGET('/admin/environments').respond(errors);

    environmentsService.loadEnvironments().then(function(result) {
      expect(result).toEqual()
    });

    httpBackend.flush();
  });
});
