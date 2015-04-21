require_relative '../test_helper'

describe Webhook do
  let(:webhook_attributes) { { :branch => 'master', :stage_id => 1, :project_id => 1, source: 'any_ci'} }

  describe '#create' do
    it 'creates the webhook' do
      assert_difference  'Webhook.count', +1 do
        Webhook.create!(webhook_attributes)
      end
    end

    it 'refuses to create a duplicate webhook' do
      Webhook.create!(webhook_attributes)

      assert_raise ActiveRecord::RecordInvalid do
        Webhook.create!(webhook_attributes)
      end
    end

    it 'recreates a webhook after soft_delete' do
      webhook = Webhook.create!(webhook_attributes)

      assert_difference  'Webhook.count', -1 do
        webhook.soft_delete!
      end

      assert_difference  'Webhook.count', +1 do
        Webhook.create!(webhook_attributes)
      end
    end
  end

  describe '#soft_delete!' do
    let(:webhook) { Webhook.create!(webhook_attributes) }

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

    # We have validation to stop us from having multiple of the same webhook active.
    # lets ensure that same validation doesn't stop us from having multiple of the same webhook soft-deleted.
    it 'can soft delete duplicate webhooks' do
      assert_difference  'Webhook.count', -1 do
        webhook.soft_delete!
      end

      webhook2 = Webhook.create!(webhook_attributes)
      assert_difference  'Webhook.count', -1 do
        webhook2.soft_delete!
      end
    end
  end

  describe '.for_source' do
    before do
      %w[any_ci any_code github travis tddium any].each_with_index do |source, index|
        Webhook.create(branch: 'master', stage_id: index, project_id: 1, source: source)
      end
    end

    it 'filters correctly' do
      assert_equal Webhook.for_source('ci', 'travis').pluck(:source), ['any_ci', 'travis', 'any']
      assert_equal Webhook.for_source('code', 'github').pluck(:source), ['any_code', 'github', 'any']
    end
  end
end
