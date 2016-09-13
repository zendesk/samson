# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 8

describe Changeset::IssueComment do
  describe ".valid_webhook" do
    let(:webhook_data) do
      {
        github: {},
        comment: {
          body: '[samson review]'
        },
      }.with_indifferent_access
    end

    it 'is valid for new comments' do
      webhook_data[:github][:action] = 'created'
      Changeset::IssueComment.valid_webhook?(webhook_data).must_equal true
    end

    it 'is not valid for deleted comments' do
      webhook_data[:github][:action] = 'deleted'
      Changeset::IssueComment.valid_webhook?(webhook_data).must_equal false
    end

    it 'is not valid for edited comments' do
      webhook_data[:github][:action] = 'edited'
      Changeset::IssueComment.valid_webhook?(webhook_data).must_equal false
    end
  end
end
