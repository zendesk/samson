require_relative '../test_helper'

describe 'zendesk hooks' do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }
  let(:next_stages) { [ stages(:test_production), stages(:test_production_pod) ] }
  let(:fake_deploy) { Hashie::Mash.new(url: 'abc') }

  describe :after_deploy do
    it 'kicks off the next stages in the deploy' do
      stage.update!(next_stage_ids: next_stages.map(&:id))
      DeployService.any_instance.expects(:deploy!).returns(fake_deploy).twice
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end

    it 'does not deploy another if the next_stage_id is nil' do
      DeployService.any_instance.expects(:new).never
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end
end
