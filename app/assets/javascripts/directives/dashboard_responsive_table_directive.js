samson.directive('dashboardResponsiveTable', function ($timeout) {
  return {
    restrict: 'A',
    link: function ($scope, element, attrs) {
      if ($scope.$last && $scope.$parent.$last) {
        $timeout(function() {
          $('.large-table-responsive .table').first().dashboardFixTable($scope.$parent.$parent.projects);
        }, 1000);  // timeout hack to let the deploy_group_versions.json responses come back in after last repeat
        // TODO: reduce timer and run check on value until css loaded into projects
      }
    }
  };
});

// Create custom jquery function to generate the fixed table
(function ($) {
  $.fn.dashboardFixTable = function (projects) {
    if ($(this).find('thead').length > 0 && $(this).find('th').length > 0) {
      // Select main table data
      var $w = $(window),
        $t = $(this),
        $thead = $t.find('thead').clone(),  // Get header
        $col = $t.find('thead, tbody').clone(),  // Get header and body
        $p = projects;
      console.log($p);

      // Create the 3 overlaying tables to fix the header and first column
      $t.after('<table class="table fix-head" /><table class="table fix-col" /><table class="table fix-int" />');

      // Static references for key positional elements
      var $fixHead = $t.siblings('.fix-head'),
        $fixCol = $t.siblings('.fix-col'),
        $fixInt = $t.siblings('.fix-int'),
        $fixWrap = $t.parent('.large-table-responsive');

      // Complete tables
      $fixHead.append($thead);
      $fixCol
        .append($col)
        .find('thead tr th:gt(0)').remove()
        .end()
        .find('tbody tr').each(function (i) {
          $(this).find('td:gt(0)').remove();
          if ($p[i].css && $p[i].css.length>0) {
            if ($p[i].css.tr_class.length > 0) $(this).addClass($p[i].css.tr_class);
            if ($p[i].css.style.length > 0) $(this).css($p[i].css.style);
          }
      });
      $fixInt.html('<thead><tr><th>' + $t.find('thead th:first-child').html() + '</th></tr></thead>');

      var setSize = function () {
          var headerWidth = 0;  // Safari fix
          $t
            .find('thead th').each(function (i) {  //set widths for .fix-head
              $fixHead.find('th').eq(i).css({
                width: $(this).outerWidth(),
                "min-width": $(this).outerWidth()  // Safari & Firefox fix
              });
              headerWidth += $(this).outerWidth();
            })
            .end()
            .find('tr').each(function (i) {  // set row heights for .fix-col
            $fixCol.find('tr').eq(i).height($(this).height());
          });

          // set header row height for .fix-int, .fix-head
          $fixInt.find('thead tr').add($fixHead.find('thead tr')).height($t.find('thead tr').height());
          // Set col 1 width for .fix-int, .fix-col
          $fixCol.find('th').add($fixCol.find('tr td:first-child')).add($fixInt.find('th')).width($t.find('thead th').width());

          $fixHead.css({
            width: headerWidth,
            "min-width": headerWidth  // Safari fix
          });
        },

        repositionFixedHead = function () {
          // Position .fix-head based on viewport scrollTop
          if ($w.scrollTop() > $t.offset().top && $w.scrollTop() < $t.offset().top + $t.outerHeight() - calcAllowance()) {
            // The header would be out of the screen
            $fixHead.add($fixInt).css({
              opacity: 1,
              top: $w.scrollTop() - $t.offset().top
            });
          } else {
            // .fix-head is in screen or table is out of the screen
            $fixHead.add($fixInt).css({
              opacity: 0,
              top: 0
            });
          }
        },

        repositionFixedCol = function () {
          if ($fixWrap.scrollLeft() > 0) {
            // When .fix-col is left of the wrapping div
            $fixCol.add($fixInt).css({
              opacity: 1,
              left: $fixWrap.scrollLeft()
            });
          } else {
            // When .fix-col is in view of the wrapping div
            $fixCol
              .css({opacity: 0})
              .add($fixInt).css({left: 0});
          }
        },

        calcAllowance = function () {
          // returns .fix-head height + height of lesser of 3 rows or 20% of viewport height
          var a = 0;
          $t.find('tbody tr:lt(3)').each(function () {
            a += $(this).height();
          });
          if (a > $w.height() * 0.2) {
            a = $w.height() * 0.2;
          }
          a += $fixHead.height();
          return a;
        };

      setSize();

      $fixWrap.scroll(function () {
        repositionFixedHead();
        repositionFixedCol();
      });

      $w
        .resize(function () {
          setSize();
          repositionFixedHead();
          repositionFixedCol();
        })
        .scroll(repositionFixedHead);
    }
  };
})(jQuery);