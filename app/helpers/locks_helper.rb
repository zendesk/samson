# frozen_string_literal: true
module LocksHelper
  def delete_lock_options
    [
      ['1 hour', 1, 'hours'],
      ['2 hours', 2, 'hours'],
      ['4 hours', 4, 'hours'],
      ['8 hours', 8, 'hours'],
      ['1 day', 1, 'days'],
      ['Never', 0, '']
    ]
  end

  def lock_icon
    icon_tag "lock"
  end

  def warning_icon
    icon_tag "warning-sign"
  end

  def global_locks
    return @global_locks if defined?(@global_locks)
    @global_locks = Lock.global
  end

  def render_locks(resource)
    locks = (resource == :global ? global_locks : Lock.for_resource(resource))
    render partial: '/locks/lock', collection: locks, as: :lock if locks.any?
  end

  def resource_lock_icon(resource)
    return unless lock = Lock.for_resource(resource).first
    text = (lock.warning? ? "#{warning_icon} Warning" : "#{lock_icon} Locked")
    content_tag :span, text.html_safe, class: "label label-warning", title: strip_tags(lock.summary)
  end

  def lock_affected(lock)
    if lock.resource_type == "Stage"
      "stage"
    elsif lock.resource
      link_to_resource lock.resource
    else
      link_to "ALL STAGES", projects_path
    end
  end
end
