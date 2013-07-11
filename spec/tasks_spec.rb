require_relative "spec_helper"

describe "Pusher::tasks" do
  describe "a GET to /tasks" do
    before { get "/tasks" }

    it "should be ok" do
      last_response.should be_ok
    end
  end

  describe "a GET to /tasks/:id" do
    before do
      task = Task.create(:name => "test", :command => "true")
      get "/tasks/#{task.id}"
    end

    it "should be ok" do
      last_response.should be_ok
    end
  end

  describe "a GET to /tasks/new" do
    before { get "/tasks/new" }

    it "should be ok" do
      last_response.should be_ok
    end
  end

  describe "a PUT to /tasks/:id" do
    let(:task) { Task.create(:name => "test", :command => "true") }

    before do
      put "/tasks/#{task.id}", params
    end

    describe "valid" do
      let(:params) {{ :task => { :name => "tester", :command => "false" }}}

      it "should redirect" do
        last_response.location.should match(%r{/tasks$})
      end

      it "should update" do
        task.reload

        task.name.should == "tester"
        task.command.should == "false"
      end
    end

    describe "invalid" do
      let(:params) {{ :task => { :command => nil }}}

      it "should render" do
        last_response.should be_ok
      end
    end
  end

  describe "a POST to /tasks" do
    before do
      post "/tasks", params
    end

    describe "valid" do
      let(:params) {{ :task => { :name => "test", :command => "true" }}}

      it "should redirect" do
        last_response.location.should match(%r{/tasks$})
      end
    end

    describe "invalid" do
      let(:params) {{ :task => { :name => "test" }}}

      it "should render" do
        last_response.should be_ok
      end
    end
  end

  describe "a GET to /tasks/:id/execute" do
    before do
      task = Task.create(:name => "test", :command => "echo 'hi'")
      get "/tasks/#{task.id}/execute"
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
