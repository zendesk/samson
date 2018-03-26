# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe RollbarDashboards::Setting do
  let(:project) { projects(:test) }

  def dashboard(overrides = {})
    attributes = {
      project: project,
      base_url: 'http://thegurn.org',
      read_token: '1234'
    }.merge(overrides)

    RollbarDashboards::Setting.new(attributes)
  end

  describe 'validations' do
    it 'is valid' do
      assert_valid dashboard
    end

    it 'is invalid if missing base_url' do
      refute_valid_on dashboard(base_url: nil), :base_url, "Base url can't be blank"
    end

    it 'is invalid if missing read_token' do
      refute_valid_on dashboard(read_token: nil), :read_token, "Read token can't be blank"
    end
  end
end
