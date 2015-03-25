require_relative '../test_helper'

describe DeployGroupsController do
  let(:deploy_group) { deploy_groups(:pod1) }

  as_a_viewer do
    describe "#show" do
      it "renders" do
        get :show, id: deploy_group
        assert_template :show
      end
    end

    describe '#deploys' do
      let(:production_deploy) { deploys(:succeeded_production_test) }

      it 'renders json list of deploys with projects' do
        get :deploys, id: deploy_group
        result = Hashie::Mash.new(JSON.parse(response.body))
        result.deploys.map(&:id).include?(production_deploy.id).must_equal true
        deploy_index = result.deploys.index { |deploy| deploy['id'] == production_deploy.id }
        deploy_index.wont_be_nil
        result.deploys[deploy_index].project.name.must_equal production_deploy.project.name
      end

      it 'handles a deploy_group with no deploys or stages' do
        new_deploy_group = DeployGroup.create!(name: 'test666', environment: deploy_group.environment)
        get :deploys, id: new_deploy_group
        result = Hashie::Mash.new(JSON.parse(response.body))
        result.deploys.must_equal []
      end
    end
  end
end
