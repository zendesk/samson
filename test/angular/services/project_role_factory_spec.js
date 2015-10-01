'use strict';

describe("Factory: projectRoleFactory", function() {

  var projectRoleFactory;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function(_projectRoleFactory_) {
    projectRoleFactory = _projectRoleFactory_;
  }));

  it('should create a new object from the given attributes', function() {
    var something = projectRoleFactory.buildFromJson({id: 0, display_name: 'Something'});
    var something_else = projectRoleFactory.buildFromJson({id: 1, display_name: 'Something else'});

    expect(something.id).toBe(0);
    expect(something.display_name).toBe('Something');
    expect(something_else.id).toBe(1);
    expect(something_else.display_name).toBe('Something else');
  });
});
