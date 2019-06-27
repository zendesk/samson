# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe RollbarDashboards::DashboardsHelper do
  describe '#rollbar_dashboard_placeholder_size' do
    it 'reports correct size' do
      settings = mock(size: 2)
      rollbar_dashboard_placeholder_size(settings).must_equal 44
    end
  end

  describe '#rollbar_dashboard_container' do
    let(:path) { 'dummy/path' }
    let(:settings) { mock('RollbarDashboards::Setting', size: 1) }

    it 'renders containter div' do
      rollbar_dashboard_container(path, settings).must_equal <<~HTML.delete("\n")
        <div class="lazy-load dashboard-container" style="min-height: 22em;" data-url="dummy/path" data-delay="1000">
        </div>
      HTML
    end
  end

  describe '#item_link' do
    def setting(stubs = {account_and_project_name: 'Account/Cool-Project', base_url: 'https://rollbar-us.com/api/1'})
      @setting ||= mock(stubs)
    end

    it 'generates item link' do
      item_link('title', '123', setting).must_equal <<~HTML.delete("\n")
        <a href="https://rollbar-us.com/Account/Cool-Project/items/123">title</a>
      HTML
    end

    it 'returns item title if account_and_project_name is nil' do
      item_link('title', '123', setting(account_and_project_name: nil)).must_equal 'title'
    end

    it 'returns item title if account_and_project_name is empty string' do
      item_link('title', '123', setting(account_and_project_name: '')).must_equal 'title'
    end

    it 'handles api subdomain' do
      setting(account_and_project_name: 'Account/Cool-Project', base_url: 'https://api.rollbar.com')
      item_link('title', '123', setting).must_equal <<~HTML.delete("\n")
        <a href="https://rollbar.com/Account/Cool-Project/items/123">title</a>
      HTML
    end
  end
end
