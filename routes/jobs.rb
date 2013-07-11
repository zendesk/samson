Pusher.class_eval do
  namespace "/jobs" do
    get do
      @jobs = Job.all
      erb :"jobs/index"
    end

    get "/new" do
      @job = Job.new

      @tasks = Task.all
      @plugins = Plugin.all

      erb :"jobs/new"
    end

    get "/:id" do |id|
      @job = Job.get!(id)
      erb :"jobs/show"
    end

    post do
      @job = Job.new(params[:job])

      params[:tasks].each do |task|
        priority = params[:task_priorities][task]
        @job.job_tasks.new(:task_id => task, :priority => priority)
      end

      if @job.save
        redirect '/jobs'
      else
        @tasks = Task.all
        @plugins = Plugin.all

        erb :"jobs/new"
      end
    end

    get "/:id/execute" do |id|
      @job = Job.get!(id)

      return 200 if !request.websocket?

      request.websocket do |ws|
        connection = command = nil

        ws.onopen do
          command = CommandTail.new(@job.tasks.map(&:command).join(" && "),
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
