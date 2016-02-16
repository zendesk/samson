samson.directive('statsProjectGraph', function() {
  return {
    restrict: 'E',
    scope: true,
    link: function($scope, $element) {
      $scope.$watch("data", function(newVal, oldVal) {
        if(newVal) {
          var stats = newVal.data.stats
          console.log(stats)
          var pos = 0
          var graphData = stats.map(function(elem) {
            console.log(elem);
            var tr = {
              x: pos,
              y: elem.c,
              label: {
                content: elem.name
              }
            }
            pos++;
            return tr;
          });

          var dataset = new vis.DataSet(graphData);
          var options = {
            //start: -1,
            //end: graphData.length,
            style:'bar',
            drawPoints: true,
            barChart: { align:'center' }
          } 
          var Graph2d = new vis.Graph2d($element[0], dataset, options);

        }
      })

    }
  };
});
