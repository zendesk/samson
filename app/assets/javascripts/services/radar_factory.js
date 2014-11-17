samson.factory('Radar', ['$log', '$rootScope', function($log, $rootScope) {
  var radar = {
    init: function() {
      RadarClient.alloc('deployListeners', function() {
        $log.info('Alloced deployListener, registering callbacks...');

        // Get notifications about started/finished deploys
        RadarClient.status('DeployStarted').on(function(message) {
          $rootScope.$broadcast('DeployStarted', message);
        }).sync();

        RadarClient.status('DeployFinished').on(function(message) {
          $rootScope.$broadcast('DeployFinished', message);
        }).sync();

        $log.info('Registered Factory listeners.');
      })
    }
  }

  $log.warn('Initing the radar factory');
  radar.init();
  return radar;
}]);
