# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:command) { "echo hi" }
  let(:job) { Job.create!(command: command, project: project, user: user) }
  let(:job_service) { stub(execute!: nil) }

  as_a_viewer do
    describe "#enabled" do
      it "is no_content when enabled" do
        JobExecution.expects(:enabled).returns true
        get :enabled
        assert_response :no_content
      end

      it "is accepted when disabled" do
        refute JobExecution.enabled
        get :enabled
        assert_response :accepted
      end
    end

    describe "#index" do
      before { get :index, params: {project_id: project.to_param } }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "#show" do
      describe 'with a job' do
        before { get :show, params: {project_id: project.to_param, id: job } }

        it "renders the template" do
          assert_template :show
        end
      end

      describe 'with a running job' do
        before { get :show, params: {project_id: project.to_param, id: jobs(:running_test) } }

        it "renders the template" do
          assert_template :show
        end
      end

      it "fails with unknown job" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: "job:nope"}
        end
      end

      describe "with format .text" do
        before { get :show, params: {format: :text, project_id: project.to_param, id: job } }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_deployer do
    describe "#destroy" do
      it "deletes the job" do
        delete :destroy, params: {project_id: project.to_param, id: job}
        assert_redirected_to [project, job]
        flash[:notice].must_equal 'Cancelled!'
      end

      it "is unauthorized when not allowed" do
        job.update_column(:user_id, users(:admin).id)
        delete :destroy, params: {project_id: project.to_param, id: job}
        assert_redirected_to [project, job]
        flash[:error].must_equal "You are not allowed to stop this job."
      end

      it "redirects to passed path" do
        delete :destroy, params: {project_id: project.to_param, id: job, redirect_to: '/ping'}
        assert_redirected_to '/ping'
      end
    end
  end
end
