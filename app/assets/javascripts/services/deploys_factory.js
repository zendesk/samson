samson.factory('Deploys',
  ["$filter", "$http", "$timeout", '$log', function($filter, $http, $timeout, $log) {
    var localize = $filter("localize");

    var Deploys = {
      entries: [],
      page: 1,
      loading: false,
      theEnd: false,
      url: '/deploys/recent.json',

      reload: function() {
        this.page = 1;
        this.entries = [];
        this.theEnd = false;
        this.loadMore();
      },

      loadMore: function() {
        if (this.theEnd) { return; }

        $log.warn('Loading more from: ' + this.url);
        this.loading = true;

        $http.get(this.url, { params: { page: this.page } }).
          success(function(data) {
            var deploys = data.deploys;

            if (deploys && deploys.length) {
              this.page += 1;
            } else if (deploys.length === 0) {
              this.theEnd = true;
              return;
            }

            for (var i = 0; i < deploys.length; i++) {
              deploys[i].localized_updated_at = localize(deploys[i].updated_at);
              deploys[i].updated_at_ago = moment(deploys[i].updated_at).fromNow();
              this.entries.push(deploys[i]);
            }
          }.bind(Deploys)).
          error(function() {
            alert("Failed to load more entries");
          }).
          finally(function() {
            $timeout(function() { this.loading = false; }.bind(Deploys), 500);
          });
      }
    };

    return Deploys;
  }]
);