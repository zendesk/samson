# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ProjectsHelper do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  describe "#star_for_project" do
    let(:current_user) { users(:admin) }

    it "shows unstarred star when project is not a favorite" do
      current_user.expects(:starred_project?).returns(false)
      link = star_for_project(project)
      link.must_include %(href="/projects/#{project.to_param}/stars")
      link.wont_include "starred"
      link.must_include "Star this project"
    end

    it "shows starred star when project is a favorite" do
      current_user.expects(:starred_project?).returns(true)
      link = star_for_project(project)
      link.must_include %(href="/projects/#{project.to_param}/stars")
      link.must_include "starred"
      link.must_include "Unstar this project"
    end
  end

  describe "#deployment_alert_title" do
    it 'returns the deployment alert data' do
      job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'failed')
      deploy = stage.deploys.create!(reference: 'master', job: job, project: project)
      expected_title = "#{deploy.updated_at.strftime('%Y/%m/%d %H:%M:%S')} Last deployment failed! " \
        "#{deploy.user.name} failed to deploy '#{deploy.reference}'"
      deployment_alert_title(stage.last_deploy).must_equal(expected_title)
    end
  end

  describe "#job_state_class" do
    let(:job) { jobs(:succeeded_test) }

    it "is success when succeeded" do
      job_state_class(job).must_equal 'success'
    end

    it "is failed otherwise" do
      job.status = 'pending'
      job_state_class(job).must_equal 'failed'
    end
  end

  describe "#admin_for_project?" do
    let(:current_user) { users(:admin) }

    it "works" do
      @project = projects(:test)
      admin_for_project?.must_equal true
    end
  end

  describe "#deployer_for_project?" do
    let(:current_user) { users(:deployer) }

    it "works" do
      @project = projects(:test)
      deployer_for_project?.must_equal true
    end
  end

  describe "#repository_web_link" do
    let(:current_user) { users(:admin) }
    let(:project) { projects(:test) }

    def config_mock(&block)
      Rails.application.config.samson.github.stub(:web_url, "github.com") do
        Rails.application.config.samson.gitlab.stub(:web_url, "gitlab.com", &block)
      end
    end

    it "makes github repository web link" do
      config_mock do
        link = repository_web_link(project)
        assert_includes link, "View repository on GitHub"
      end
    end

    it "makes gitlab repository web link" do
      config_mock do
        project.repository_url = "http://gitlab.com/bar/foo.git"
        link = repository_web_link(project)
        assert_includes link, "View repository on Gitlab"
      end
    end

    it "makes no local web link" do
      config_mock do
        project.repository_url = "http://localhost/bar/foo.git"
        link = repository_web_link(project)
        assert_equal link, ""
      end
    end
  end

  describe "#docker_build_methods_help_text" do
    it 'returns help text html for build methods' do
      result = docker_build_methods_help_text
      result.must_include '<b>Docker images built externally: </b>'
      result.must_include '<b>Build docker with GCB CLI: </b>'
      result.wont_include '<b>Samson manages docker images: </b>'
    end
  end
end
