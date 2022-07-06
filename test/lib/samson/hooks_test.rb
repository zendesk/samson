# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 9 # untestable minitest if/else and render_stylesheets / render_javascripts

describe Samson::Hooks do
  let(:available_plugins) { Dir['plugins/*'].map { |p| File.basename(p) } }

  describe '.plugins' do
    around do |test|
      Samson::Hooks.instance_variable_set(:@plugins, nil)
      Samson::Hooks.instance_variable_set(:@plugin_list, nil)
      test.call
      Samson::Hooks.instance_variable_set(:@plugins, nil)
      Samson::Hooks.instance_variable_set(:@plugin_list, nil)
    end

    it 'returns no plugins when not set' do
      with_env PLUGINS: nil do
        Samson::Hooks.plugins.size.must_equal 0
      end
    end

    it 'returns all the plugins when set to all' do
      with_env PLUGINS: 'all' do
        Samson::Hooks.plugins.size.must_equal available_plugins.size
      end
    end

    it 'can ignore plugins' do
      with_env PLUGINS: 'all,-kubernetes,-zendesk' do
        (available_plugins - Samson::Hooks.plugins.map(&:name)).sort.must_equal ['kubernetes', 'zendesk']
        refute Samson::Hooks.active_plugin?('kubernetes')
        refute Samson::Hooks.active_plugin?('zendesk')
        assert Samson::Hooks.active_plugin?('env')
      end
    end

    it 'can pick some plugins' do
      with_env PLUGINS: 'kubernetes, zendesk' do
        Samson::Hooks.plugins.map(&:name).sort.must_equal ['kubernetes', 'zendesk']
        assert Samson::Hooks.active_plugin?('kubernetes')
        assert Samson::Hooks.active_plugin?('zendesk')
        refute Samson::Hooks.active_plugin?('env')
      end
    end

    it "can load local plugin" do
      path = '/path/to/samson/plugins/zendesk/lib/samson_zendesk/samson_plugin.rb'
      with_env PLUGINS: 'all' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'zendesk'
      end
    end

    it "can load gem plugin" do
      path = '/path/to/gems/ruby-2.2.2/gems/samson_hipchat-0.0.0/lib/samson_hipchat/samson_plugin.rb'
      with_env PLUGINS: 'all' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'hipchat'
      end
    end
  end

  describe '.with_callback' do
    def hooks
      Samson::Hooks.send(:hooks, :stage_clone)
    end

    it 'adds a hook' do
      before = hooks.size
      before.must_be :>, 1
      Samson::Hooks.with_callback(:stage_clone, -> {}) do
        hooks.size.must_equal 1
      end
      hooks.size.must_equal before
    end

    it "can fire the extra hook" do
      called = []
      Samson::Hooks.with_callback(:stage_clone, ->(*) { called << 1 }) do
        Samson::Hooks.fire(:stage_clone, stages(:test_staging), stages(:test_staging))
        called.must_equal [1]
      end
    end
  end

  describe '.with_callbacks_for_plugin' do
    def hooks
      Samson::Hooks.send(:hooks, :error)
    end

    it 'removes all callbacks for hook except for the one for the specified plugin' do
      mock_exception = mock
      Airbrake.expects(:notify).with(mock_exception, foo: 'bar').once
      Rollbar.expects(:error).never
      Sentry.expects(:error).never

      hooks.size.must_equal 3

      Samson::Hooks.only_callbacks_for_plugin('samson_airbrake', :error) do
        hooks.size.must_equal 1
        Samson::Hooks.fire(:error, mock_exception, foo: 'bar').size.must_equal 1
      end

      hooks.size.must_equal 3
    end
  end

  describe ".render_views" do
    it "joins partials" do
      view = stub("View", render: "OUT".html_safe)
      html = Samson::Hooks.render_views(:stage_show, view)
      html.must_include "OUTOUT"
      assert html.html_safe?
    end
  end

  describe ".traced" do
    it "traces when using a traced hook" do
      Samson::PerformanceTracer.expects(:trace_execution_scoped).yields
      Samson::Hooks.send(:traced, :after_deploy) { 1 }
    end

    it "traces when using a traced hook" do
      Samson::PerformanceTracer.expects(:trace_execution_scoped).never
      Samson::Hooks.send(:traced, :deploy_group_permitted_params) { 1 }.must_equal 1
    end
  end

  describe ".view" do
    it "it adds a view hook" do
      expected = "foobar/my_view"
      Samson::Hooks.view Samson::Hooks::VIEW_HOOKS.first, expected
      Samson::Hooks.instance_variable_get(:@hooks)[Samson::Hooks::VIEW_HOOKS.first].last.must_equal expected
    end

    it "it adds the view name to the hook" do
      expected = "foobar/#{Samson::Hooks::VIEW_HOOKS.first}"
      Samson::Hooks.view Samson::Hooks::VIEW_HOOKS.first, "foobar"
      Samson::Hooks.instance_variable_get(:@hooks)[Samson::Hooks::VIEW_HOOKS.first].last.must_equal expected
    end
  end
end
