# record what was done in the console
PaperTrail.whodunnit =
  if defined?(::Rails::Console)
    "#{`whoami`.strip}: console"
  elsif defined?(Rake)
    "#{`whoami`.strip}: rake"
  end

class << PaperTrail
  def with_whodunnit(user)
    old = whodunnit
    self.whodunnit = user
    yield
  ensure
    self.whodunnit = old
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
