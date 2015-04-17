require_relative '../test_helper'

describe DeployGroupsController do
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:production_deploy) { deploys(:succeeded_production_test) }

  as_a_viewer do
    describe "#show" do
      it "renders" do
        get :show, id: deploy_group
        assert_template :show
      end

      it 'renders json list of deploys with projects' do
        get :show, id: deploy_group, format: 'json'
        result = Hashie::Mash.new(JSON.parse(response.body))
        result.deploys.map(&:id).include?(production_deploy.id).must_equal true
        deploy_index = result.deploys.index { |deploy| deploy['id'] == production_deploy.id }
        deploy_index.wont_be_nil
        result.deploys[deploy_index].project.name.must_equal production_deploy.project.name
        result.deploys[deploy_index].url.must_equal project_deploy_path(production_deploy.project, production_deploy)
      end

      it 'handles a deploy_group with no deploys or stages' do
        new_deploy_group = DeployGroup.create!(name: 'test666', environment: deploy_group.environment)
        get :show, id: new_deploy_group, format: 'json'
        result = Hashie::Mash.new(JSON.parse(response.body))
        result.deploys.must_equal []
      end

      it 'only shows successful deploy for json response' do
        failed_deploy = Deploy.create!(stage: production_deploy.stage, job: jobs(:failed_test), reference: 'master')
        get :show, id: deploy_group, format: 'json'
        result = Hashie::Mash.new(JSON.parse(response.body))
        result.deploys.map(&:id).include?(production_deploy.id).must_equal true
        result.deploys.map(&:id).include?(failed_deploy.id).must_equal false
      end
    end
  end
end
