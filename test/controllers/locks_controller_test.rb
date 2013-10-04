require 'test_helper'

describe LocksController do
  let(:project) { projects(:test) }

  setup do
    session[:user_id] = users(:admin).id
  end

  describe "a GET to #new" do
    setup do
      get :new, :project_id => project.id
    end

    it "renders template" do
      assert_template :new
    end
  end

  describe "a POST to #create" do
    setup do
      post :create, params.merge(:project_id => project.id)
    end

    describe "valid parameters" do
      let(:params) { { :job_lock => { :environment => "master1", :expires_at => 2.weeks.from_now } } }

      it "creates a new lock" do
        project.job_locks.where(:environment => "master1").count.must_equal(1)
      end

      it "redirects to the root url" do
        assert_redirected_to root_path
      end
    end

    describe "invalid parameters" do
      let(:params) { { :job_lock => { { :environment => "blah" } } }

      it "renders new template" do
        assert_template :new
      end

      it "sets a flash error" do
        request.flash[:error].wont_be_nil
      end
    end

    describe "no params" do
      let(:params) {{}}

      it "redirects to the root url" do
        assert_redirected_to root_path
      end
    end
  end

  describe "a DELETE to #destroy" do
    let(:lock) do
      project.job_locks.create!(:environment => "master1", :expires_at => 2.weeks.from_now)
    end

    setup do
      delete :destroy, :id => lock.id, :project_id => project.id
    end

    it "destroys the lock" do
      lambda { lock.reload }.must_raise(ActiveRecord::RecordNotFound)
    end

    it "redirects to the root path" do
      assert_redirected_to root_path
    end
  end
end
