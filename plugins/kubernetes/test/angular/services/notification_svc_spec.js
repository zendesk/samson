'use strict';

describe("Service: notificationService", function() {

  var messageCenterService, notificationService;

  beforeEach(function() {
    module('samson');
  });

  beforeEach(inject(function(_notificationService_, _messageCenterService_) {
    messageCenterService = _messageCenterService_;
    notificationService = _notificationService_;
  }));

  it('should use the message center service to show a flash info message', function() {
    spyOn(messageCenterService, 'add');
    notificationService.info('an info message');
    expect(messageCenterService.add).toHaveBeenCalledWith('info', 'an info message', {});
  });

  it('should use the message center service to show a flash error message', function() {
    spyOn(messageCenterService, 'add');
    notificationService.error('an error message');
    expect(messageCenterService.add).toHaveBeenCalledWith('danger', 'an error message', {});
  });

  it('should use the message center service to show a flash warning message', function() {
    spyOn(messageCenterService, 'add');
    notificationService.warning('a warning message');
    expect(messageCenterService.add).toHaveBeenCalledWith('warning', 'a warning message', {});
  });

  it('should use the message center service to show a flash error message per each error', function() {
    spyOn(messageCenterService, 'add');
    notificationService.errors(['an error message', 'another error message']);
    expect(messageCenterService.add).toHaveBeenCalledWith('danger', 'an error message', {});
    expect(messageCenterService.add).toHaveBeenCalledWith('danger', 'another error message', {});
  });

  it('should allow the caller to supply a hash with options', function() {
    spyOn(messageCenterService, 'add');
    notificationService.error('an error message', {status: messageCenterService.status.permanent});
    expect(messageCenterService.add).toHaveBeenCalledWith('danger', 'an error message', {status: messageCenterService.status.permanent});
  });
});
