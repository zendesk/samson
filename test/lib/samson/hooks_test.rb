# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 9 # untestable minitest if/else and render_stylesheets / render_javascripts

describe Samson::Hooks do
  let(:number_of_plugins) { Dir['plugins/*'].size }
  let(:plugins) { nil }

  describe '.plugins' do
    around do |test|
      with_env(PLUGINS: plugins) do
        Samson::Hooks.instance_variable_set(:@plugins, nil)
        Samson::Hooks.instance_variable_set(:@plugin_list, nil)
        test.call
        Samson::Hooks.instance_variable_set(:@plugins, nil)
        Samson::Hooks.instance_variable_set(:@plugin_list, nil)
      end
    end

    context 'when the plugins env is not set to anything' do
      it 'returns no plugins by default' do
        Samson::Hooks.plugins.size.must_equal 0
      end
    end

    context 'when the plugins env is set to all' do
      let(:plugins) { 'all' }

      it 'returns all the plugins' do
        Samson::Hooks.plugins.size.must_equal number_of_plugins
      end
    end

    context 'when ignoring plugins' do
      let(:plugins) { 'all,-kubernetes,-zendesk' }

      it 'returns the plugins that were not disabled' do
        Samson::Hooks.plugins.size.must_equal(number_of_plugins - 2)
        refute Samson::Hooks.active_plugin?('kubernetes')
        refute Samson::Hooks.active_plugin?('zendesk')
        assert Samson::Hooks.active_plugin?('env')
      end
    end

    context 'when the plugins env is set to include some plugins' do
      let(:plugins) { 'kubernetes, zendesk' }

      it 'only returns those plugins' do
        Samson::Hooks.plugins.size.must_equal 2
        assert Samson::Hooks.active_plugin?('kubernetes')
        assert Samson::Hooks.active_plugin?('zendesk')
        refute Samson::Hooks.active_plugin?('env')
      end
    end

    context 'when load via local plugin' do
      let(:plugins) { 'all' }
      let(:path) { '/path/to/samson/plugins/zendesk/lib/samson_zendesk/samson_plugin.rb' }

      it 'return correct plugin name from folder' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'zendesk'
      end
    end

    context 'when load via gem plugin' do
      let(:plugins) { 'all' }
      let(:path) { '/path/to/gems/ruby-2.2.2/gems/samson_hipchat-0.0.0/lib/samson_hipchat/samson_plugin.rb' }

      it 'return correct plugin name from Gem' do
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

      hooks.size.must_equal 2

      Samson::Hooks.only_callbacks_for_plugin('samson_airbrake', :error) do
        hooks.size.must_equal 1
        Samson::Hooks.fire(:error, mock_exception, foo: 'bar').size.must_equal 1
      end

      hooks.size.must_equal 2
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
