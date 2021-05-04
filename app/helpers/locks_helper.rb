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
    render partial: '/locks/lock', collection: locks, as: :lock, locals: {show_resolve: resource} if locks.any?
  end

  def resource_lock_icon(resource)
    return unless locks = Lock.for_resource(resource).presence
    text = (locks.all?(&:warning?) ? "#{warning_icon} Warning" : "#{lock_icon} Locked")
    text += " (#{locks.count})" if locks.count > 1
    title = locks.map { |lock| strip_tags(lock.summary) }.join("\n")
    content_tag :span, text.html_safe, class: "label label-warning", title: title
  end

  def lock_affected(lock)
    if lock.resource_type == "Stage"
      "Stage #{lock.resource.name}"
    elsif lock.resource
      link_to_resource lock.resource, with_locks: false
    else
      link_to "ALL STAGES", projects_path
    end
  end
end
