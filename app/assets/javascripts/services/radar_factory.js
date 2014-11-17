samson.factory('Radar', ['$log', '$rootScope', function($log, $rootScope) {
  var radar = {
    init: function() {
      RadarClient.alloc('deployListeners', function() {
        // Get notifications about started/finished deploys
        RadarClient.status('DeployCreated').on(function(message) {
          $rootScope.$broadcast('DeployCreated', message);
        }).sync();

        RadarClient.status('DeployStarted').on(function(message) {
          $rootScope.$broadcast('DeployStarted', message);
        }).sync();

        RadarClient.status('DeployFinished').on(function(message) {
          $rootScope.$broadcast('DeployFinished', message);
        }).sync();
      })
    }
  }

  radar.init();
  return radar;
}]);
