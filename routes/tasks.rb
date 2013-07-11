require 'sinatra-websocket'

Pusher.class_eval do
  namespace "/tasks" do
    helpers TasksHelper

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

    get "/:id/edit" do |id|
      @task = Task.get!(id)
      erb :"tasks/edit"
    end

    get "/:id/execute" do |id|
      @task = Task.get!(id)

      return 200 if !request.websocket?

      request.websocket do |ws|
        connection = command = nil

        ws.onopen do
          ws.send("Executing \"#{@task.command}\" and tailing the output...\n")

          command = CommandTail.new(@task.command,
            proc {|message| ws.send(message.force_encoding("utf-8"))},
            proc { ws.close_websocket })
        end

        ws.onmessage do |msg|
          command.close if msg == "close"
        end
      end
    end

    put "/:id" do |id|
      @task = Task.get!(id)
      @task.attributes = params[:task]

      if @task.save
        redirect '/tasks'
      else
        erb :"tasks/edit"
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
