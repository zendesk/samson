require 'sinatra-websocket'
require 'pty'

Pusher.class_eval do
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
        connection = command = nil

        ws.onopen do
          ws.send("Executing \"#{@task.command}\" and tailing the output...\n")

          command = CommandTail.new(@task.command) do |message|
            ws.send(message)
          end
        end

        ws.onmessage do |msg|
          if msg == "close"
            command.close
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
