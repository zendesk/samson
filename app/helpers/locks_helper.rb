# frozen_string_literal: true
module LocksHelper
  def delete_lock_options
    [
      ['Expire in 1 hour', 1.hour],
      ['Expire in 2 hours', 2.hours],
      ['Expire in 4 hours', 4.hours],
      ['Expire in 8 hours', 8.hours],
      ['Expire in 1 day', 1.day],
      ['Never', nil]
    ]
  end

  def lock_icon
    icon_tag "lock"
  end

  def warning_icon
    icon_tag "warning-sign"
  end

  def global_lock
    return @global_lock if defined?(@global_lock)
    @global_lock = Lock.global.first
  end

  def render_lock(resource)
    lock = (resource == :global ? global_lock : Lock.for_resource(resource).first)
    render '/locks/lock', lock: lock if lock
  end

  def resource_lock_icon(resource)
    return unless lock = Lock.for_resource(resource).first
    text = (lock.warning? ? "#{warning_icon} Warning" : "#{lock_icon} Locked")
    content_tag :span, text.html_safe, class: "label label-warning", title: strip_tags(lock.summary)
  end
end
