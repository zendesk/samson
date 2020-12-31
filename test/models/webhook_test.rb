# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Webhook do
  let(:stage) { stages(:test_staging) }
  let(:webhook_attributes) do
    {
      branch: 'master',
      stage: stage,
      project: stage.project,
      source: 'any_ci'
    }
  end

  describe '#create' do
    it 'creates the webhook' do
      assert_difference 'Webhook.count', +1 do
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

      assert_difference 'Webhook.count', -1 do
        webhook.soft_delete!(validate: false)
      end

      assert_difference 'Webhook.count', +1 do
        Webhook.create!(webhook_attributes)
      end
    end
  end

  describe '#soft_delete!' do
    let!(:webhook) { Webhook.create!(webhook_attributes) }

    it 'deletes the webhook' do
      assert_difference 'Webhook.count', -1 do
        webhook.soft_delete!(validate: false)
      end
    end

    it 'soft deletes the webhook' do
      assert_difference  'Webhook.with_deleted { Webhook.count} ', 0 do
        webhook.soft_delete!(validate: false)
      end
    end

    # We have validation to stop us from having multiple of the same webhook active.
    # lets ensure that same validation doesn't stop us from having multiple of the same webhook soft-deleted.
    it 'can soft delete duplicate webhooks' do
      assert_difference 'Webhook.count', -1 do
        webhook.soft_delete!(validate: false)
      end

      webhook2 = Webhook.create!(webhook_attributes)
      assert_difference 'Webhook.count', -1 do
        webhook2.soft_delete!(validate: false)
      end
    end
  end

  describe '#validate_not_auto_deploying_without_buddy' do
    it "is valid without a stage" do
      webhook = Webhook.new(webhook_attributes.except(:stage))
      refute_valid webhook
      webhook.errors[:stage].must_equal ["must exist"]
    end

    it "shows error when trying to setup auto-deploy without buddy" do
      stage.stubs(:deploy_requires_approval?).returns(true)
      webhook = Webhook.new(webhook_attributes)
      refute_valid webhook
      webhook.errors[:stage].must_equal ["cannot be used for a stage the requires approval"]
    end
  end

  describe '.for_source' do
    before do
      ['any_ci', 'any_code', 'github', 'travis', 'tddium', 'any'].each_with_index do |source, index|
        Webhook.create!(webhook_attributes.merge(branch: "master#{index}", source: source))
      end
    end

    it 'filters correctly' do
      Webhook.for_source('ci', 'travis').pluck(:source).must_equal ['any_ci', 'travis', 'any']
      Webhook.for_source('code', 'github').pluck(:source).must_equal ['any_code', 'github', 'any']
    end
  end

  describe '.for_branch' do
    before do
      ['', 'master', 'feature/branch'].each_with_index do |branch, index|
        Webhook.create!(webhook_attributes.merge(branch: branch, stage: Stage.all.to_a[index]))
      end
    end

    it 'filters correctly' do
      Webhook.for_branch('feature/branch').pluck(:branch).must_equal ['', 'feature/branch']
      Webhook.for_branch('master').pluck(:branch).must_equal ['', 'master']
    end
  end

  describe '.for_source' do
    Samson::Integration::SOURCES.each do |release_source|
      it 'is true when the source matches' do
        assert Webhook.source_matches?(release_source, 'release_type', release_source)
      end

      it "is false when the source doesn't match" do
        refute Webhook.source_matches?('poop', 'release_type', release_source)
      end

      it 'is always true if the source is any' do
        assert Webhook.source_matches?('any', 'release_type', release_source)
      end
    end

    it "is true if the source type matches" do
      assert Webhook.source_matches?('any_code', 'code', 'github')
    end
  end

  describe '.active' do
    it 'returns only active webhooks' do
      Webhook.create!(webhook_attributes.merge(disabled: true))
      active_webhook = Webhook.create!(webhook_attributes.merge(branch: 'develop'))
      Webhook.active.must_equal([active_webhook])
    end
  end
end
