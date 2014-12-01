require_relative '../test_helper'

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
      data = deployment_alert_data(project, stage)
      data[:url].must_equal project_deploy_path(project, deploy)
      data[:reference].must_equal deploy.reference
      data[:timestamp].must_equal deploy.updated_at.strftime('%m/%d/%Y %H:%M:%S')
      data[:user].must_equal deploy.user.name
    end

  end
end
