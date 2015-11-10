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

  function showStep(step) {
    $scope.steps[step - 1].current = true;
    $scope.currentStep = step;
  }

  $scope.isCurrentStep = function(step) {
    return step == $scope.currentStep;
  };

  showStep(1);
});
