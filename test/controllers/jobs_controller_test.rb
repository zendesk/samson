require 'test_helper'
require 'fakeredis'

describe JobsController do
  let(:project) { projects(:test) }
  let(:admin) { users(:admin) }

  let(:job) do
    project.job_histories.create!(
      environment: "master1",
      sha: "master",
      user_id: admin.id
    )
  end

  as_a_viewer do
    describe "a GET to :index" do
      setup { get :index }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :active" do
      setup { get :active }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :show" do
      describe "with a valid job" do
        setup { get :show, project_id: project.id, id: job.to_param }

        it "renders the template" do
          assert_template :show
        end
      end

      describe "with no job" do
        setup { get :show, project_id: project.id, id: "deploy:nope" }

        it "redirects to the root page" do
          assert_redirected_to root_path
        end

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end
      end
    end

    describe "a POST to :create" do
      setup { post :create, project_id: project.id }
      it_is_unauthorized
    end

    describe "a PUT to :update" do
      setup { put :update, project_id: project.id, id: job.to_param }
      it_is_unauthorized
    end

    describe "a DELETE to :destroy" do
      setup { delete :destroy, project_id: project.id, id: job.to_param }
      it_is_unauthorized
    end
  end

  as_a_admin do
    describe "a POST to :create" do
      setup { post :create, params.merge(project_id: project.id) }

      describe "with valid params" do
        let(:params) {{ job: {
          environment: "master1",
          sha: "master"
        }}}

        let(:job) { project.job_histories.last }

        teardown do
          Thread.main[:deploys].each(&:kill)
          Thread.main[:deploys].clear
        end

        it "redirects to the job path" do
          assert_redirected_to project_job_path(project, job)
        end

        it "creates a deploy" do
          Thread.main[:deploys].size.must_equal(1)
        end
      end

      describe "with invalid params" do
        let(:params) {{ job: { environment: "nope" } }}

        it "redirects to the project path" do
          assert_redirected_to project_path(project)
        end

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end
      end

      describe "with missing params" do
        let(:params) {{}}

        it "redirects to the root path" do
          assert_redirected_to root_path
        end
      end
    end

    describe "a PUT to :update" do
      describe "with a blank message" do
        setup { put :update, :project_id => project.id, :id => job.to_param, :job => { :message => "" } }

        it "is unprocessable" do
          response.status.must_equal(422)
        end
      end

      as_a_deployer do
        describe "when not the job creator" do
          setup { put :update, :project_id => project.id, :id => job.to_param, :job => { :message => "hello" } }

          it "is forbidden" do
            response.status.must_equal(403)
          end
        end
      end

      describe "valid" do
        setup { put :update, :project_id => project.id, :id => job.to_param, :job => { :message => "hello" } }

        it "sets the redis channel" do
          Redis.driver.get("#{job.channel}:input").must_equal("hello")
        end

        it "responds ok" do
          response.status.must_equal(200)
        end
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a valid deploy" do
        let(:deploy) { MiniTest::Mock.new }

        setup do
          deploy.expect(:job_id, job.id)
          deploy.expect(:stop, true)

          Thread.main[:deploys] << { :deploy => deploy }

          delete :destroy, project_id: project.id, id: job.to_param
        end

        teardown { Thread.main[:deploys].clear }

        it "stops the deploy" do
          deploy.verify
        end
      end

      describe "with a different deploy" do
        let(:deploy) { MiniTest::Mock.new }

        setup do
          deploy.expect(:job_id, "RANDOMNESS")
          Thread.main[:deploys] << { :deploy => deploy }

          delete :destroy, project_id: project.id, id: job.to_param
        end

        teardown { Thread.main[:deploys].clear }

        it "stops the deploy" do
          deploy.verify
        end
      end

      as_a_deployer do
        setup do
          delete :destroy, project_id: project.id, id: job.to_param
        end

        it "is forbidden" do
          response.status.must_equal(403)
        end
      end

      describe "without a valid deploy" do
        setup { delete :destroy, :project_id => project.id, :id => job.to_param }

        it "responds 404" do
          response.status.must_equal(404)
        end
      end
    end
  end
end
