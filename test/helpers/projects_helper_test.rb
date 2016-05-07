require_relative '../test_helper'

SingleCov.covered!

describe ProjectsHelper do
  describe "#star_link" do
    let(:project) { projects(:test) }
    let(:current_user) { users(:admin) }
    let(:stage) { stages(:test_staging) }

    it "star a project" do
      current_user.stubs(:starred_project?).returns(false)
      link =  star_for_project(project)
      assert_includes link, %{href="/stars?id=#{project.to_param}"}
      assert_includes link, %{data-method="post"}
    end

    it "unstar a project" do
      current_user.stubs(:starred_project?).returns(true)
      link =  star_for_project(project)
      assert_includes link, %{href="/stars/#{project.to_param}"}
      assert_includes link, %{data-method="delete"}
    end

    it 'returns the deployment alert data' do
      job = project.jobs.create!(command: 'cat foo', user: users(:deployer), status: 'failed')
      deploy = stage.deploys.create!(reference: 'master', job: job)
      expected_title = "#{deploy.updated_at.strftime('%Y/%m/%d %H:%M:%S')} Last deployment failed! #{deploy.user.name} failed to deploy '#{deploy.reference}'"
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
end
