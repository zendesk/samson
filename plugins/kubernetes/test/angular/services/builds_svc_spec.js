'use strict';

describe("Service: buildsService", function() {

  var buildsService, httpBackend, buildFactory, httpErrorService;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_buildsService_, $httpBackend, _buildFactory_, _httpErrorService_) {
    buildsService = _buildsService_;
    httpBackend = $httpBackend;
    buildFactory = _buildFactory_;
    httpErrorService = _httpErrorService_;
  }));

  afterEach(function() {
    httpBackend.verifyNoOutstandingExpectation();
    httpBackend.verifyNoOutstandingRequest();
  });


  it('should handle GET request for loading the builds', function() {
    var response = {
        builds:[
          {id: 0, label: 'an build'},
          {id: 1, label: 'another build'}
        ]
    };

    httpBackend.expectGET('/projects/a_project_id/builds').respond(response);

    buildsService.loadBuilds('a_project_id').then(function(builds) {
      expect(builds).toEqual(response.builds.map(buildFactory.build));
    });

    httpBackend.flush();
  });
});
