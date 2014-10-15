require_relative '../test_helper'

describe Webhook do
  let(:webhook_params) { { :branch => 'master', :stage_id => 1, :project_id => 1} }

  describe 'creation' do
    it 'creates the webhook' do
      assert_difference  'Webhook.count', +1 do
        Webhook.create!(webhook_params)
      end
    end
  end

  describe 'deletion' do
    let(:webhook) { Webhook.create!(webhook_params) }

    before { webhook }

    it 'deletes the webhook' do
      assert_difference  'Webhook.count', -1 do
        webhook.soft_delete!
      end
    end

    it 'soft deletes the webhook' do
      assert_difference  'Webhook.with_deleted { Webhook.count} ', 0 do
        webhook.soft_delete!
      end
    end
  end
end
