describe("Timeline", function() {
  beforeEach(module("samson"));

  describe("filters", function() {
    var filter;

    describe("utility filters", function() {
      describe("visualizeStatus filter", function() {
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
