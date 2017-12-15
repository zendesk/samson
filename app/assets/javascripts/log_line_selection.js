// Users can click on log lines to highlight them and get a shareable url
$(function() {
  var HASH_REGEX = /^#L(\d+)(?:-L(\d+))?$/;
  var $highlightedLines;
  var LINES_SELECTOR = '#messages span';

  function linesFromHash() {
    var result = HASH_REGEX.exec(window.location.hash);
    if (result === null) {
      return [];
    } else {
      return result.slice(1);
    }
  }

  function addHighlight(start, end) {
    if (!start) {
      return;
    }
    start = Number(start) - 1;
    if (end) {
      end = Number(end);
    } else {
      end = start + 1;
    }
    $highlightedLines = $(LINES_SELECTOR).slice(start, end).addClass('highlighted');
  }

  function removeHighlight() {
    if ($highlightedLines) {
      $highlightedLines.removeClass('highlighted');
    }
  }

  function highlightAndScroll() {
    highlight();
    scroll();
  }

  function scroll() {
    if ($highlightedLines && $highlightedLines.get(0)) {
      $highlightedLines.get(0).scrollIntoView(true);
    }
  }

  function highlight() {
    removeHighlight();
    var nextLines = linesFromHash();
    addHighlight.apply(this, nextLines); // explode arguments
  }

  function indexOfLine() {
    // the jQuery map passes an index before the element
    var line = arguments[arguments.length - 1];
    return $(line).index(LINES_SELECTOR) + 1;
  }

  $('#messages').on('click', 'span', function(event) {
    if ($(event.target).is('a')) { return; } // let users click on links
    event.preventDefault();
    var clickedNumber = indexOfLine($(event.currentTarget));
    var shift = event.shiftKey;
    if (shift && $highlightedLines.length) {
      var requestedLines = $highlightedLines.map(indexOfLine);
      requestedLines.push(clickedNumber);
      requestedLines = requestedLines.sort(function(a, b) {
        return a - b;
      });
      var end = requestedLines.length - 1;
      window.location.hash = 'L' + requestedLines[0] + '-L' + requestedLines[end];
    } else {
      window.location.hash = 'L' + clickedNumber;
    }
    highlight();
  });

  highlightAndScroll();
});
