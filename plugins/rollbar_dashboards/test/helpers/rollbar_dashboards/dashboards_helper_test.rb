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
end
