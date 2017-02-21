$(function(){
  var $messages = $("#messages"),
      old_height = $messages.css('max-height'),
      expanded = false,
      following = true;

  // Reduces overhead with throttle, since it is triggered often by contentchanged when old content streams in
  // (scrollHeight + height would be good enough, but over-scrolling does not harm)
  var scrollToBottom = _.throttle(function() {
    $messages.scrollTop($messages.prop("scrollHeight"));
  }, 250);

  function shrinkOutput() {
    expanded = false;
    $messages.css("max-height", old_height);
  }

  function expandOutput() {
    expanded = true;
    $messages.css("max-height", "none");
  }

  // also toggles the button that will be on the finished page so deploys that stop transition cleanly
  function activateModalButton($current) {
    $("#output-options > button, #output-expand-toggle").removeClass("active");
    $current.addClass("active");
  }

  $("#output-follow").click(function() {
    activateModalButton($(this));

    following = true;

    shrinkOutput();

    scrollToBottom();
  });

  $("#output-no-follow").click(function() {
    activateModalButton($(this));

    following = false;

    shrinkOutput();
  });

  $("#output-expand").click(function() {
    activateModalButton($("#output-expand-toggle, #output-expand"));

    following = false;

    expandOutput();
  });

  // on finished pages we only have the 'Expand' button, so it toggles
  $("#output-expand-toggle").click(function() {
    var $self = $(this);

    if($self.hasClass("active")) {
      shrinkOutput();
      $self.removeClass("active");
    } else {
      expandOutput();
      $self.addClass("active");
    }
  });

  // When a message is added via stream.js
  $messages.bind('contentchanged', function() {
    // show the output and hide buddy check
    var $output = $('#output');
    if ($output.find('.output').hasClass("hidden") ) {
      $output.find('.output').removeClass('hidden');
      $output.find('.deploy-check').hide();
    }

    // scroll when following to see new content
    // setTimeout so we scroll after content was inserted
    // this triggers the .scroll below, so be careful of triggering loops
    if (following) { setTimeout(scrollToBottom, 0); }
  });

  // when user scrolls all the way down, start following
  // when user scrolls up, stop following since it would cause jumping
  // (adds 30 px wiggle room since the math does not quiet add up)
  // ... do nothing when in expanded view
  $messages.scroll(function() {
    if(expanded) { return; }
    var position = $messages.prop("scrollHeight") - $messages.scrollTop() - $messages.height() - 30;
    if(position > 0 && following) {
      $("#output-no-follow").click();
    } else if (position < 0 && !following) {
      $("#output-follow").click();
    }
  });
});
