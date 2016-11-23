# frozen_string_literal: true

class << PaperTrail
  undef_method :whodunnit= # nobody uses this directly and we should never use the default papertrail before_actions
  attr_reader :whodunnit_user

  # record what was done in the console
  def default_whodunnit
    if defined?(::Rails::Console)
      "#{`whoami`.strip}: console"
    elsif defined?(Rake)
      "#{`whoami`.strip}: rake"
    end
  end

  def with_whodunnit_user(user)
    old = @whodunnit_user
    @whodunnit_user = user
    yield
  ensure
    @whodunnit_user = old
  end

  def whodunnit
    @whodunnit_user&.id || default_whodunnit
  end

  def with_logging
    was_enabled = PaperTrail.enabled?
    was_enabled_for_controller = PaperTrail.enabled_for_controller?
    PaperTrail.enabled = true
    PaperTrail.enabled_for_controller = true
    begin
      yield
    ensure
      PaperTrail.enabled = was_enabled
      PaperTrail.enabled_for_controller = was_enabled_for_controller
    end
  end
end
