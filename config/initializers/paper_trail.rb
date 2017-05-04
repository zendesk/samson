# frozen_string_literal: true
# record what was done in the console
PaperTrail.whodunnit =
  if defined?(::Rails::Console)
    "#{`whoami`.strip}: console"
  elsif defined?(Rake)
    "#{`whoami`.strip}: rake"
  end

PaperTrail.config.track_associations = false

class << PaperTrail
  undef_method :whodunnit= # nobody uses this directly and we should never use the default papertrail before_actions
  attr_reader :whodunnit_user

  def with_whodunnit_user(user)
    old = @whodunnit_user
    @whodunnit_user = user
    yield
  ensure
    @whodunnit_user = old
  end

  def whodunnit
    @whodunnit_user&.id
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

# using record_update would otherwise record all nil attributes, which will break history display and be invalid
# record_update sets @in_after_callback, so we need to reset it from inside of object_attrs_for_paper_trail
PaperTrail::RecordTrail.prepend(Module.new do
  def record_outside_update
    @outside_after_callback = true
    record_update true
  ensure
    @outside_after_callback = false
  end

  def object_attrs_for_paper_trail
    old = @in_after_callback
    @in_after_callback = false if @outside_after_callback
    super
  ensure
    @in_after_callback = old
  end
end)
