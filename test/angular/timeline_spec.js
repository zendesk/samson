describe("Timeline", function() {
  beforeEach(module("samson"));

  var scope;

  describe("filters", function() {
    var filter;

    describe("filter filters", function() {
      var deploys;

      beforeEach(function() {
        deploys = [
          {
            user: { name: "abc" },
            project: { name: "big project" },
            production: false,
            status: "succeeded"
          },
          {
            user: { name: "boss" },
            project: { name: "big project" },
            production: true,
            status: "failed"
          },
          {
            user: { name: "travis" },
            project: { name: "big project" },
            production: false,
            status: "cancelled"
          },
          {
            user: { name: "semaphore" },
            project: { name: "bigger project" },
            production: false,
            status: "pending"
          },
          {
            user: { name: "admin" },
            project: { name: "awesome app" },
            production: true,
            status: "errored"
          },
          {
            user: { name: "tddium" },
            project: { name: "awesome app" },
            production: false,
            status: "cancelling"
          },
          {
            user: { name: "someone" },
            project: { name: "super tool" },
            production: false,
            status: "running"
          }
        ];
      });

      describe("project and user filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("projectUserFilter");
        }));

        it("does not filter if nothing is entered", function() {
          expect(filter(deploys, null).length).toBe(deploys.length);
          expect(filter(deploys, undefined).length).toBe(deploys.length);
          expect(filter(deploys, "").length).toBe(deploys.length);
        });

        it("finds project names", function() {
          expect(filter(deploys, "big project").length).toBe(3);
        });

        it("finds user name", function() {
          expect(filter(deploys, "boss").length).toBe(1);
        });

        it("ignores case", function() {
          expect(filter(deploys, "BOSS").length).toBe(1);
        });

        it("finds partial matches", function (){
          expect(filter(deploys, "some").length).toBe(3);
        });
      });

      describe("user filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("userFilter");
        }));

        it("does not filter if nothing is selected", function() {
          expect(filter(deploys, null).length).toBe(deploys.length);
          expect(filter(deploys, undefined).length).toBe(deploys.length);
        });

        it("finds human deploys", function() {
          expect(filter(deploys, "Human").length).toBe(4);
        });

        it("finds robot deploys", function() {
          expect(filter(deploys, "Robot").length).toBe(3);
        });
      });

      describe("stage filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("stageFilter");
        }));

        it("does not filter if nothing is selected", function() {
          expect(filter(deploys, null).length).toBe(deploys.length);
          expect(filter(deploys, undefined).length).toBe(deploys.length);
        });

        it("finds non-production deploys", function() {
          expect(filter(deploys, false).length).toBe(5);
        });

        it("finds production deploys", function() {
          expect(filter(deploys, true).length).toBe(2);
        });
      });

      describe("status filter", function() {
        beforeEach(inject(function($filter) {
          filter = $filter("statusFilter");
        }));

        it("does not filter if nothing is selected", function() {
          expect(filter(deploys, null).length).toBe(deploys.length);
          expect(filter(deploys, undefined).length).toBe(deploys.length);
        });

        it("finds successful deploys", function() {
          expect(filter(deploys, "Successful").length).toBe(1);
        });

        it("finds non-successful deploys", function() {
          expect(filter(deploys, "Unsuccessful").length).toBe(3);
        });

        it("finds not finished deploys", function() {
          expect(filter(deploys, "Unfinished").length).toBe(3);
        });
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
          filter = $filter("visualizeStatus");
        }));

        it("transforms deploy status to visual status", function() {
          expect(filter("running")).toEqual("primary");
          expect(filter("succeeded")).toEqual("success");
          expect(filter("failed")).toEqual("danger");
          expect(filter("pending")).toEqual("info");
          expect(filter("cancelling")).toEqual("warning");
          expect(filter("cancelled")).toEqual("danger");
          expect(filter("errored")).toEqual("danger");
        });
      });
    });
  });
});
