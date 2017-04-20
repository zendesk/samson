# frozen_string_literal: true
# Make rack not complain when puma restarts the server with the same pid
# can be removed if rails s + kill -USR1 <PID> works
# https://github.com/rack/rack/blob/master/lib/rack/server.rb#L379-L393
# see https://github.com/puma/puma/issues/1060 + https://github.com/rack/rack/issues/1159
::Rack::Server.prepend(Module.new do
  def pidfile_process_status
    if ::File.exist?(options[:pid]) && ::File.read(options[:pid]).to_i == Process.pid
      Rails.logger.info " * PUMA in-place restart detected"
      :dead
    else
      super
    end
  end
end)
