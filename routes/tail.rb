require 'sinatra-websocket'

Pusher.class_eval do
  class Readable < EventMachine::Connection
    def initialize(*args)
      @socket = args.first
    end

    def notify_readable
      @socket.send(@io.readline)
    end
  end

  set :sockets, []

  get "/tail" do
    return 200 if !request.websocket?

    request.websocket do |ws|
      connection = nil

      ws.onopen do
        connection = EventMachine.watch(IO.popen("tail -f -n 0 /var/log/system.log"), Readable, ws)
        connection.notify_readable = true
      end

      ws.onclose do
        connection.detach
      end
    end
  end
end
