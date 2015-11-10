'use strict';

describe("Service: httpErrorService", function() {

  var httpErrorService, httpBackend;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($httpBackend, _httpErrorService_) {
    httpBackend = $httpBackend;
    httpErrorService = _httpErrorService_;
  }));

  it('should handle a failed http response with a client error and error data in the response', function() {
    var result = httpErrorService.handleResponse({
      status: 400,
      statusText: 'Bad request',
      data: {
        errors: ['Some error', 'Another error']
      }
    });

    expect(result).toBeDefined();
    expect(result.type).toBe('error');
    expect(result.messages).toEqual(['Some error', 'Another error']);
  });

  it('should handle a failed http response with a client error and error data in the response', function() {
    var result = httpErrorService.handleResponse({
      status: 400,
      statusText: 'Bad request'
    });

    expect(result).toBeDefined();
    expect(result.type).toBe('error');
    expect(result.messages).toEqual(['Bad request']);
  });

  it('should handle a failed http response with a server error', function() {
    var result = httpErrorService.handleResponse({
      status: 500,
      statusText: 'Internal server error'
    });

    expect(result).toBeDefined();
    expect(result.type).toBe('error');
    expect(result.messages).toEqual(['Due to a technical error, the request could not be completed. Please, try again later.']);
  });

  it('should allow to create a custom result type with a single message', function() {
    var result = httpErrorService.createResultType('warning', 'some warning');

    expect(result).toBeDefined();
    expect(result.type).toBe('warning');
    expect(result.messages).toEqual(['some warning']);
  });

  it('should allow to create a custom result type with multiple messages', function() {
    var result = httpErrorService.createResultType('warning', ['some warning', 'another warning']);

    expect(result).toBeDefined();
    expect(result.type).toBe('warning');
    expect(result.messages).toEqual(['some warning', 'another warning']);
  });
});
