require "sinatra/streaming"

Pusher.class_eval do
  set :jobs, {}

  namespace "/jobs" do
    helpers JobsHelper
    helpers Sinatra::Streaming

    get do
      @jobs = Job.all
      erb :"jobs/index"
    end

    get "/new" do
      @job = Job.new
      erb :"jobs/new"
    end

    get "/:id" do |id|
      @job = Job.get!(id)
      erb :"jobs/show"
    end

    get "/:id/edit" do |id|
      @job = Job.get!(id)
      erb :"jobs/edit"
    end

    post do
      @job = Job.new(params[:job])

      add_job_tasks

      if @job.save
        redirect '/jobs'
      else
        erb :"jobs/new"
      end
    end

    put "/:id" do |id|
      @job = Job.get!(id)
      @job.attributes = params[:job] if params[:job]

      result = false

      # HAHAHAHA Fuck you DataMapper
      # It won't let you delete from
      # a "has n" collection
      @job.transaction do |t|
        @job.job_tasks.destroy
        add_job_tasks
        t.rollback unless (result = @job.save)
      end

      if result
        redirect '/jobs'
      else
        erb :"jobs/edit"
      end
    end

    post "/:id/plugins/:plugin_id" do |id, plugin_id|
      @job = Job.get!(id)
      @job.job_plugins.new(:plugin_id => plugin_id, :position => params[:position] || @job.job_plugins.size)
      @job.save

      redirect "/jobs/#{id}"
    end

    get "/:id/stream" do |id|
      @job = Job.get!(id)

      stream(:keep_open) do |io|
        settings.jobs[@job.id] << io

        io.callback do
          settings.jobs[@job.id].delete(io)
        end

        io.errback do
          settings.jobs[@job.id].delete(io)
        end
      end
    end

    get "/:id/execute" do |id|
      @job = Job.get!(id)

      return 200 if !request.websocket?

      request.websocket do |ws|
        connection = command = nil

        ws.onopen do
          settings.jobs[@job.id] = [ws]

          command = CommandTail.new(command_string,
            proc {|msg| settings.jobs[@job.id].each {|socket| socket.respond_to?(:write) ? socket.write(msg.force_encoding("utf-8")) : socket.send(msg.force_encoding("utf-8"))}},
            proc { settings.jobs[@job.id].each {|socket| socket.close_websocket }})
        end

        ws.onmessage do |msg|
          command.close if msg == "close"
        end
      end
    end
  end
end
