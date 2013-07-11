require_relative "spec_helper"

describe "Pusher::jobs" do
  describe "a GET to /jobs" do
    before { get "/jobs" }

    it "should be ok" do
      last_response.should be_ok
    end
  end

  describe "a GET to /jobs/:id" do
    before do
      job = Job.create(:name => "test")
      get "/jobs/#{job.id}"
    end

    it "should be ok" do
      last_response.should be_ok
    end
  end

  describe "a GET to /jobs/new" do
    before { get "/jobs/new" }

    it "should be ok" do
      last_response.should be_ok
    end
  end

  describe "a PUT to /jobs/:id" do
    let(:job) { Job.create(:name => "tester") }

    before do
      put "/jobs/#{job.id}", params
    end

    describe "valid" do
      let(:params) {{ :job => { :name => "test" }}}

      it "should redirect" do
        last_response.location.should match(%r{/jobs$})
      end
    end

    describe "updating the task sort" do
      let(:params) do
        job.tasks << Task.create(:name => "test", :command => "true")
        job.tasks << Task.create(:name => "tester", :command => "false")
        job.save

        {
          :tasks => job.tasks.map(&:id),
          :task_priorities => "tasks[]=#{job.tasks.last.id}&tasks[]=#{job.tasks.first.id}"
        }
      end

      it "should update" do
        tasks = job.tasks
        job.reload.tasks.should == tasks.reverse
      end
    end

    describe "adding a task" do
      let(:task) { Task.create(:name => "tester", :command => "false") }
      let(:params) do
        job.tasks << Task.create(:name => "test", :command => "true")
        job.save

        { :tasks => job.tasks.map(&:id).push(task.id) }
      end

      it "should update" do
        job.reload.tasks.should include(task)
      end
    end

    describe "removing a task" do
      let(:task) { Task.create(:name => "test", :command => "true") }

      let(:params) do
        job.tasks << Task.create(:name => "tester", :command => "false")
        job.tasks << task
        job.save

        { :tasks => [task.id] }
      end

      it "should update" do
        job.reload.tasks.should == [task]
      end
    end

    describe "invalid" do
      let(:params) {{ :job => { :name => nil } }}

      it "should render" do
        last_response.should be_ok
      end
    end
  end

  describe "a POST to /jobs" do
    before do
      post "/jobs", params
    end

    describe "valid" do
      let(:params) {{ :job => { :name => "test" }}}

      it "should redirect" do
        last_response.location.should match(%r{/jobs$})
      end
    end

    describe "adding and sorting tasks" do
      let(:tasks) {[
        Task.create(:name => "tester", :command => "true"),
        Task.create(:name => "falser", :command => "false"),
      ]}

      let(:params) {{
        :job => { :name => "test" },
        :tasks => tasks.map(&:id),
        :task_priorities => "tasks[]=#{tasks.last.id}&tasks[]=#{tasks.first.id}"
      }}

      it "should redirect" do
        last_response.location.should match(%r{/jobs$})
      end

      it "should setup tasks" do
        Job.last.tasks.should == tasks.reverse
      end
    end

    describe "invalid" do
      let(:params) {{ :job => {} }}

      it "should render" do
        last_response.should be_ok
      end
    end
  end

  describe "a GET to /jobs/:id/execute" do
    before do
      job = Job.create(:name => "test")
      get "/jobs/#{job.id}/execute"
    end

    describe "with websockets" do
      # TODO ......
    end

    describe "without websockets" do
      it "should be ok" do
        last_response.should be_ok
      end
    end
  end
end
