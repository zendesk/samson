# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe RollbarDashboards::DashboardsHelper do
  describe '#rollbar_dashboard_placeholder_size' do
    it 'reports correct size' do
      settings = mock(size: 2)
      rollbar_dashboard_placeholder_size(settings).must_equal 36
    end
  end

  describe '#rollbar_lazy_load_dashboard_container' do
    let(:path) { 'dummy/path' }
    let(:settings) { mock('RollbarDashboards::Setting', size: 1) }

    it 'renders containter div' do
      rollbar_lazy_load_dashboard_container(path, settings).must_equal <<~HTML.delete("\n")
        <div class="lazy-load dashboard-container" style="min-height: 18em;" data-url="dummy/path" data-delay="1000">
        </div>
      HTML
    end
  end

  describe '#rollbar_item_link' do
    let(:setting) do
      RollbarDashboards::Setting.new(
        project: projects(:test),
        base_url: 'http://thegurn.org',
        account_and_project_name: "Foo/Bar",
        read_token: '1234'
      )
    end

    it 'generates item link' do
      rollbar_item_link('title', '123', setting).must_equal <<~HTML.delete("\n")
        <a href="http://thegurn.org/Foo/Bar/items/123">title</a>
      HTML
    end

    it 'returns item title if account_and_project_name is blank' do
      setting.account_and_project_name = nil
      rollbar_item_link('title', '123', setting).must_equal 'title'
    end
  end
end
