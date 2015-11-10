'use strict';

describe("Controller: KubernetesReleaseWizardCtrl", function() {
  var $rootScope, $scope, controller;

  beforeEach(function() {
    module("samson");
  });

  beforeEach(inject(function($controller, _$rootScope_) {
    $rootScope = _$rootScope_;
    $scope = $rootScope.$new();

    controller = $controller('KubernetesReleaseWizardCtrl', {
      $scope: $scope
    });
  }));

  describe('when the controller is initialized', function() {
    it('should update the current step', function() {
      assertCurrentStep(1);
    });

    it('should update the current flag in each step', function() {
      assertSteps(1);
    });
  });

  describe('moving to the next step', function() {
    it('should update the current step', function() {
      $scope.next();
      assertCurrentStep(2);
    });

    it('should update the current flag in each step', function() {
      $scope.next();
      assertSteps(2);
    });
  });

  describe('moving to the previous step', function() {
    it('should update the current step', function() {
      $scope.next();
      assertCurrentStep(2);

      $scope.previous();
      assertCurrentStep(1);
    });

    it('should update the current flag in each step', function() {
      $scope.next();
      assertSteps(2);

      $scope.previous();
      assertSteps(1);
    });
  });

  function assertCurrentStep(currentStep) {
    expect($scope.currentStep).toBe(currentStep);
  }

  function assertSteps(currentStep) {
    _.each($scope.steps, function(step){
      var current = (step.step == currentStep);
      expect(step.current).toBe(current);
    });
  }
});
