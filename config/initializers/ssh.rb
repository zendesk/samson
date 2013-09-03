Net::SSH::Connection::Session.class_eval do
  alias :old_loop :loop
  # Non-blocking loop, Net::SSH doesn't
  # let us pass through when using start
  def loop(wait = 0, &block)
    old_loop(wait, &block)
  end
end
