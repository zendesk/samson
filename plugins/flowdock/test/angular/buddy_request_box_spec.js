describe('Buddy requests notifications', function () {

  describe("factory: Mentionbox", function () {
    var flowdock;
    var rootScope;
    var mentionBox;
    var users;

    beforeEach(module("samson"));

    // Setup the mock service in an anonymous module.
    beforeEach(function () {
      inject(function ($injector) {
        users = [
          { id:1, name: 'test', avatar: 'fake', type: 'contact' },
          { id: 2, name: 'another_name', avatar: 'fake', type: 'contact' }
        ];
        rootScope = $injector.get('$rootScope');
        flowdock = $injector.get('Flowdock');
        flowdock.users = function () {
          rootScope.$emit('flowdock_users', users);
          return users
        };
        mentionBox = $injector.get('Mentionbox');
      });
    });

    it('returns the data filtered', function () {
      expect(mentionBox).toBeDefined();
      expect(mentionBox.filteredData('te')).toEqual(users.slice(0, 1));
    });

    it('inits the JQuery mention box plugin', function() {
      var instance = mentionBox.init('#test_id', 'This is the default message');
      expect(mentionBox.mentionsId).toEqual('#test_id');
      expect(mentionBox.defaultMessage).toEqual('This is the default message');
      expect(instance.message).toBeDefined();
    });

    it('draws a mentions box after the root scope emits flowdock_users event', function () {
      spyOn(mentionBox, 'draw');
      rootScope.$emit('flowdock_users', []);
      expect(mentionBox.draw).toHaveBeenCalled();
    });

    it('formats the data in the expected format by flowdock', function () {
      var mentions = 'Some text the @[test](test user name) has inserted mentioning @[test2](test2 user name)';
      var expected = 'Some text the @test has inserted mentioning @test2';
      expect(mentionBox.reformatMessage(mentions)).toEqual(expected);
    });
  });

  describe("factory: Flowdock", function () {
    var flowdock;
    var $httpBackend;
    var $rootScope;

    beforeEach(module("samson"));

    // Setup the mock service in an anonymous module.
    beforeEach(function () {
      inject(function ($injector) {
        flowdock = $injector.get('Flowdock');
        $httpBackend = $injector.get('$httpBackend');
        $rootScope = $injector.get('$rootScope');
      });
    });

    afterEach(function () {
      $httpBackend.flush();
      $httpBackend.verifyNoOutstandingExpectation();
      $httpBackend.verifyNoOutstandingRequest();
    });

    it('should get the users from server', function () {
      expect(flowdock).toBeDefined();
      expect($httpBackend).toBeDefined();
      var expected_users = [{ id: 1, name: 'test', avatar: 'fake_avatar', type: 'contact' }];
      $httpBackend.when('GET', '/flowdock/users').respond(200, { users: expected_users });
      $httpBackend.expectGET('/flowdock/users');
      $rootScope.$on('flowdock_users', function (event, users){
        expect(users).toEqual(expected_users);
      });
      flowdock.users();
    });

    it('should send a buddy request', function () {
      var post_data;
      post_data = { deploy_id: 1, message: 'A test message'};
      $httpBackend.when('POST', '/flowdock/notify', post_data).respond(200, { message: 'Successfully sent a buddy request!'});
      $httpBackend.expectPOST('/flowdock/notify', post_data);
      flowdock.buddyRequest(1, 'A test message');
    });
  });

  describe('BuddyNotificationCtrl', function () {
    var buddyNotificationsCtrl, scope, flowdock, rootScope;

    // Setup the mock service in an anonymous module.
    beforeEach(module("samson"));
    beforeEach(function () {
      inject(function ($injector) {
        flowdock = $injector.get('Flowdock');
        rootScope = $injector.get('$rootScope');
        flowdock.users = function () {
          var users = [{ id: 1, name: 'test', avatar: 'fake', type: 'contact' }];
          rootScope.$emit('flowdock_users', users);
          return users
        };
        flowdock.buddyRequest = jasmine.createSpy('My Method');
      });
    });

    beforeEach(inject(function ($controller) {
      var dependencies;
      scope = rootScope.$new();
      scope.deploy = 1;
      dependencies = { $scope: scope, $rootScope: rootScope, Flowdock: flowdock };
      buddyNotificationsCtrl = $controller('BuddyNotificationsCtrl', dependencies);
    }));

    it('should send a buddy_request notification', function () {
      setTimeout(function () {
        buddyNotificationsCtrl.notificationBox.message = function (callback) {
          callback.call('Some message');
        };
        expect(flowdock.buddyRequest).toHaveBeenCalledWith('Some message');
        buddyNotificationsCtrl.notifyFlowDock();
      }, 100);
    });
  });
});
