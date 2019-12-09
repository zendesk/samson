# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:command) { "echo hi" }
  let(:job) { Job.create!(command: command, project: project, user: user) }
  let(:job_service) { stub(execute: nil) }

  as_a :viewer do
    unauthorized :delete, :destroy, project_id: :foo, id: 1

    describe "#enabled" do
      it "is no_content when enabled" do
        JobQueue.expects(:enabled).returns true
        get :enabled
        assert_response :no_content
      end

      it "is accepted when disabled" do
        refute JobQueue.enabled
        get :enabled
        assert_response :accepted
      end
    end

    describe "#index" do
      before { get :index, params: {project_id: project.to_param} }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "#show" do
      it "renders pending" do
        get :show, params: {project_id: project.to_param, id: job}
        assert_template :show
      end

      it "renders running job" do
        get :show, params: {project_id: project.to_param, id: jobs(:running_test)}
        assert_template :show
      end

      it "fails with unknown job" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: "job:nope"}
        end
      end

      it "renders logs when requesting text" do
        get :show, params: {project_id: project.to_param, id: job}, format: :text
        response.media_type.must_equal "text/plain"
        response.header["Content-Disposition"].must_match /\.log"/
      end

      describe "header" do
        it "renders headers for jobs" do
          get :show, params: {project_id: project.to_param, id: job, header: true}
          response.body.must_include "Viewer is about to execute"
          response.body.wont_include "<html"
        end

        it "renders headers for jobs with deploys" do
          get :show, params: {project_id: project.to_param, id: jobs(:succeeded_test), header: true}
          response.body.must_include "Foo - Deploy"
          response.body.wont_include "<html"
        end
      end
    end
  end

  as_a :project_deployer do
    describe "#destroy" do
      it "deletes the job" do
        delete :destroy, params: {project_id: project.to_param, id: job}
        assert_redirected_to [project, job]
        flash[:notice].must_equal 'Cancelled!'
      end

      it "redirects to passed path" do
        delete :destroy, params: {project_id: project.to_param, id: job, redirect_to: '/ping'}
        assert_redirected_to '/ping'
      end
    end
  end
end
