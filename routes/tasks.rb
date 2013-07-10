require 'sinatra-websocket'
require 'open3'

Pusher.class_eval do
  class Readable < EventMachine::Connection
    def initialize(socket)
      super

      @socket = socket
    end

    def notify_readable
      @socket.send(@io.readline)
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
        connection = nil

        ws.onopen do
          io = IO.popen("#{@task.command} 2>&1")
          connection = EventMachine.watch(io, Readable, ws)
          connection.notify_readable = true
        end

        ws.onclose { connection.detach }
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
