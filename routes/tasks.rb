require 'sinatra-websocket'
require 'pty'

Pusher.class_eval do
  class Readable < EventMachine::Connection
    def initialize(socket)
      super

      @socket = socket
    end

    def notify_readable
      while buffer = @io.read_nonblock(4096)
        @socket.send(buffer)
      end
    rescue EOFError, Errno::EAGAIN
    end
  end

  namespace "/tasks" do
    get "/new" do
      @task = Task.new

      erb :"tasks/new"
    end

    get do
      @tasks = Task.all
      erb :"tasks/index"
    end

    get "/:id" do |id|
      @task = Task.get!(id)
      erb :"tasks/show"
    end

    get "/:id/execute" do |id|
      @task = Task.get!(id)

      return 200 if !request.websocket?

      request.websocket do |ws|
        connection = io = pid = nil

        ws.onopen do
          ws.send("Executing \"#{@task.command}\" and tailing the output...\n")

          io, _, pid = PTY.spawn(@task.command)

          connection = EventMachine.watch(io, Readable, ws)
          connection.notify_readable = true
        end

        ws.onmessage do |msg|
          if msg == "close"
            Process.kill("INT", pid)

            ws.send(io.read)

            connection.detach
            io.close

            ws.close_websocket
          end
        end
      end
    end

    post do
      @task = Task.new(params[:task])

      if @task.save
        redirect '/tasks'
      else
        erb :"tasks/new"
      end
    end
  end
end
