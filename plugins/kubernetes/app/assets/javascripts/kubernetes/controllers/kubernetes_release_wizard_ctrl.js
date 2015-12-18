samson.controller('KubernetesReleaseWizardCtrl', function($scope) {
  $scope.steps = [
    {
      step: 1,
      current: false
    },
    {
      step: 2,
      current: false
    }
  ];

  $scope.next = function() {
    showStep($scope.currentStep + 1);
  };

  $scope.previous = function() {
    showStep($scope.currentStep - 1);
  };

  function showStep(new_step) {
    $scope.currentStep = new_step;
    _.each($scope.steps, function(step) {
      step.current = $scope.isCurrentStep(step.step);
    });
  }

  $scope.isCurrentStep = function(step) {
    return step == $scope.currentStep;
  };

  showStep(1);
});
