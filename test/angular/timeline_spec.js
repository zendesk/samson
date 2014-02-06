describe("Timeline", function() {
  beforeEach(module("pusher"));

  var scope;

  describe("filters", function() {
    var filter;

    describe("filter filters", function() {
      var deploys;

      beforeEach(function() {
        deploys = [
          {
            user: "abc",
            stageType: false
          },
          {
            user: "boss",
            stageType: true
          },
          {
            user: "travis",
            stageType: false
          },
          {
            user: "semaphore",
            stageType: false
          },
          {
            user: "admin",
            stageType: true
          }
        ];
      });

      describe("user filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("userFilter");
        }));

        it("filters deploys by user type", function() {
          expect(filter(deploys, "Human").length).toBe(3);
          expect(filter(deploys, "Robot").length).toBe(2);
        });
      });

      describe("stage filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("stageFilter");
        }));

        it("filters deploys by stage type", function() {
          expect(filter(deploys, false).length).toBe(3);
          expect(filter(deploys, true).length).toBe(2);
        })
      });
    });

    describe("time filters", function() {
      describe("fullDate filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("fullDate");
        }));

        it("consumes an object and returns the date in a year", function() {
          expect(filter({day: "Tuesday", month: "January", year: "2010", date: "28"})).toBe("Tuesday, 28 January 2010");
        });
      });

      describe("localize filter", function() {
        function timezoneAdjustment(t) {
          var DEV_TIMEZONE  = 660,
              TEST_TIMEZONE = - (new Date()).getTimezoneOffset();
              timezoneDiff  = DEV_TIMEZONE - TEST_TIMEZONE;
          return t + timezoneDiff * 60000;
        }

        beforeEach(inject(function($filter) {
          filter = $filter("localize");
        }));

        it("consumes a UTC time in ms [int] and returns an object representing the local datetime", function() {
          expect(filter(timezoneAdjustment(12345678000))).toEqual({
            year: 1970,
            month: "May",
            date: 24,
            day: "Sunday"
          });
          expect(filter(timezoneAdjustment(765432100000))).toEqual({
            year: 1994,
            month: "April",
            date: 4,
            day: "Monday"
          });
        });
      })
    });

    describe("utility filters", function() {
      describe("statusToIcon filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("statusToIcon");
        }));

        it("transforms deploy status to visual status", function() {
          expect(filter("running")).toEqual("plus-sign primary");
          expect(filter("succeeded")).toEqual("ok-sign success");
          expect(filter("failed")).toEqual("remove-sign danger");
          expect(filter("pending")).toEqual("minus-sign info");
          expect(filter("cancelling")).toEqual("exclamation-sign warning");
          expect(filter("cancelled")).toEqual("ban-circle danger");
        });
      });
    });
  });
});
