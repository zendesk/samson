require "sinatra/streaming"

Pusher.class_eval do
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

    get "/:id/stream" do |id|
      @job = Job.get!(id)

      stream(:keep_open) do |io|
        command = CommandTail.new(@job.tasks.map(&:command).join("\r\n"),
          proc {|msg| io.write(msg.force_encoding("utf-8")) },
          proc { io.close })

        io.callback { command.close }
        io.errback { command.close }
      end
    end

    get "/:id/execute" do |id|
      @job = Job.get!(id)

      return 200 if !request.websocket?

      request.websocket do |ws|
        connection = command = nil

        ws.onopen do
          command = CommandTail.new(@job.tasks.map(&:command).join("\r\n"),
            proc {|msg| ws.send(msg.force_encoding("utf-8"))},
            proc { ws.close_websocket })
        end

        ws.onmessage do |msg|
          command.close if msg == "close"
        end
      end
    end
  end
end
