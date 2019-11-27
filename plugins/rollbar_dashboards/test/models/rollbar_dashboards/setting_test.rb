# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe RollbarDashboards::Setting do
  let(:project) { projects(:test) }
  let(:dashboard) do
    RollbarDashboards::Setting.new(
      project: project,
      base_url: 'http://thegurn.org',
      account_and_project_name: "Foo/Bar",
      read_token: '1234'
    )
  end

  describe 'validations' do
    it 'is valid' do
      assert_valid dashboard
    end

    it 'is invalid if missing base_url' do
      dashboard.base_url = nil
      refute_valid_on dashboard, :base_url, "Base url can't be blank"
    end

    it 'is invalid if missing read_token' do
      dashboard.read_token = nil
      refute_valid_on dashboard, :read_token, "Read token can't be blank"
    end

    it 'is invalid if missing account_and_project_name' do
      dashboard.account_and_project_name = nil
      refute_valid_on dashboard, :account_and_project_name, "Account and project name can't be blank"
    end

    it 'is valid with previously missing account_and_project_name' do
      dashboard.save!
      dashboard.account_and_project_name = nil
      assert_valid dashboard
    end
  end

  describe "items_url" do
    it "is nil when account_and_project_name is not set" do
      dashboard.account_and_project_name = ""
      refute dashboard.items_url
    end

    it "builds" do
      dashboard.items_url.must_equal "http://thegurn.org/Foo/Bar/items"
    end

    it "can deal with api. urls" do
      dashboard.base_url = "https://api.rollbar.com/foo"
      dashboard.items_url.must_equal "https://rollbar.com/Foo/Bar/items"
    end
  end
end
