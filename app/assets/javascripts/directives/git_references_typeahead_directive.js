samson.directive('gitReferencesTypeahead', function() {
  return {
    restrict: 'E',
    templateUrl: 'shared/_git_references_typeahead.tmpl.html',
    scope: {
      selectedReference: '&'
    },
    controller: function($scope, $stateParams, $q, $timeout, $http) {
      $scope.reference = undefined;
      $scope.warnings = [];
      $scope.status = undefined;
      $scope.submitting = false;

      $scope.loadReferences = function(val) {
        //Performs a search against the local search index.
        var deferred = $q.defer();
        engine.search(val, function(data) {
          deferred.resolve(data);
        });

        return deferred.promise.then(function(data) {
          return data;
        });
      };

      $scope.checkStatus = function() {
        if (this.timeoutPromise) {
          $timeout.cancel(this.timeoutPromise);
        }

        this.timeoutPromise = $timeout(function() {
          checkReference($scope.reference);
        }, 100);
      };

      $scope.shouldDisableControl = function() {
        return $scope.submitting;
      };

      $scope.shouldDisableButton = function() {
        return !_.isEmpty($scope.warnings) || $scope.submitting;
      };

      $scope.$on('gitReferenceSubmissionStart', function(event) {
        $scope.submitting = true;
        clearStatus();
      });

      $scope.$on('gitReferenceSubmissionCompleted', function(event) {
        $scope.submitting = false;
        $scope.reference = undefined;
      });

      /************************************************************************************
       Internal functions
       ************************************************************************************/

      function clearStatus() {
        $scope.warnings = [];
        $scope.status = undefined;
      }

      function checkReference(reference) {
        if (_.isUndefined(reference) || _.isEmpty(reference)) {
          clearStatus();
        }
        else {
          $http.get('/projects/' + $stateParams.project_id + '/commit_statuses', {params: {ref: reference}}).then(
            function(response) {
              clearStatus();

              // If the current reference no longer matches the scope by the time this promise is resolved,
              // the status is ignored
              if (reference == $scope.reference) {
                switch (response.data.status) {
                  case "success":
                    $scope.status = "has-success";
                    break;
                  case "pending":
                    $scope.status = "has-warning";
                    $scope.warnings = data.status_list;
                    break;
                  case "failure":
                  case "error":
                    $scope.status = "has-error";
                    $scope.warnings = data.status_list;
                    break;
                  case null:
                    $scope.status = "has-error";
                    $scope.warnings = [{"state": "Tag or SHA", description: "'" + reference + "' does not exist"}];
                    break;
                }
              }
            });
        }
      }

      /************************************************************************************
       Initialization
       ************************************************************************************/

      //Initializes the engine and prefetches the current references for the project
      var engine = new Bloodhound({
        datumTokenizer: function(d) {
          return Bloodhound.tokenizers.whitespace(d);
        },
        queryTokenizer: Bloodhound.tokenizers.whitespace,
        limit: 100,
        prefetch: {
          url: '/projects/' + $stateParams.project_id + '/references.json',
          ttl: 30000
        }
      });

      engine.initialize();
    }
  };
});
