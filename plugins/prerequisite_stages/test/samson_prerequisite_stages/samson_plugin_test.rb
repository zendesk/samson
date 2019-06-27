# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonPrerequisiteStages do
  let(:stage1) { stages(:test_staging) }
  let(:stage2) { stages(:test_production) }
  let(:deploy) { stage1.deploys.first }

  before do
    stage1.update_attributes!(prerequisite_stage_ids: [stage2.id])
  end

  describe SamsonPrerequisiteStages::Engine do
    describe '.validate_deployed_to_all_prerequisite_stages' do
      it 'shows unmet prerequisite stages' do
        stage1.expects(:undeployed_prerequisite_stages).with(deploy.reference).returns([stage2])
        error = SamsonPrerequisiteStages.validate_deployed_to_all_prerequisite_stages(stage1, deploy.reference)
        error.must_equal "Reference 'staging' has not been deployed to these prerequisite stages: Production."
      end

      it 'is silent when there are no unmet prerequisites' do
        stage1.expects(:undeployed_prerequisite_stages).with(deploy.reference).returns([])
        SamsonPrerequisiteStages.validate_deployed_to_all_prerequisite_stages(stage1, deploy.reference).must_be_nil
      end
    end
  end

  describe 'event callbacks' do
    describe 'before_deploy callback' do
      only_callbacks_for_plugin :before_deploy

      it 'raises if a prerequisite stage has not been deployed for ref' do
        stage1.expects(:undeployed_prerequisite_stages).with(deploy.reference).returns([stage2])

        error_message = "Reference 'staging' has not been deployed to these prerequisite stages: Production."
        error = assert_raises RuntimeError do
          Samson::Hooks.fire(:before_deploy, deploy, nil)
        end
        error.message.must_equal error_message
      end

      it 'does not raise if ref has not been deployed' do
        stage1.expects(:undeployed_prerequisite_stages).with(deploy.reference).returns([])

        Samson::Hooks.fire(:before_deploy, deploy, nil)
      end
    end

    describe 'ref_status callback' do
      only_callbacks_for_plugin :ref_status

      it 'returns status if stage does not meet prerequisites' do
        stage1.expects(:undeployed_prerequisite_stages).with(deploy.reference).returns([stage2])

        error_message = "Reference 'staging' has not been deployed to these prerequisite stages: Production."
        expected = {
          state: 'fatal',
          statuses: [{
            state: 'Unmet Prerequisite Stages',
            description: error_message
          }]
        }

        Samson::Hooks.fire(:ref_status, stage1, deploy.reference).must_include expected
      end

      it 'returns nil if stage meets prerequisites' do
        stage1.expects(:undeployed_prerequisite_stages).with(deploy.reference).returns([])
        Samson::Hooks.fire(:ref_status, stage1, deploy.reference).must_equal [nil]
      end
    end

    describe 'stage_permitted_params callback' do
      it 'includes prerequisite_stage_ids' do
        Samson::Hooks.fire(:stage_permitted_params).must_include prerequisite_stage_ids: []
      end
    end
  end

  describe 'view callbacks' do
    before do
      view_context.instance_variable_set(:@project, stage1.project)
      view_context.instance_variable_set(:@stage, stage1)
    end

    let(:view_context) do
      view_context = ActionView::Base.new(ActionController::Base.view_paths)

      class << view_context
        include Rails.application.routes.url_helpers
        include ApplicationHelper
      end

      view_context.instance_eval do
        # stub for testing render
        def protect_against_forgery?
        end
      end

      view_context
    end

    describe 'stage_form callback' do
      def with_form
        view_context.form_for [stage1.project, stage1] do |form|
          yield form
        end
      end

      def render_view
        with_form do |form|
          Samson::Hooks.render_views(:stage_form, view_context, form: form)
        end
      end

      it 'renders prerequisite stage checkboxes' do
        result = render_view
        result.must_include '<legend>Prerequisite Stages</legend>'
        result.must_include %(<input type="checkbox" value="#{stage2.id}")
        result.wont_include %(<input type="checkbox" value="#{stage1.id}")
      end
    end

    describe 'stage_show callback' do
      def render_view
        Samson::Hooks.render_views(:stage_show, view_context)
      end

      it 'shows prerequisite stages' do
        result = render_view
        result.must_include '<h2>Prerequisite Stages</h2>'
        result.must_match /<li>\n.*href="\/projects\/foo\/stages\/production"/
      end

      it 'shows nothing if no prerequisite stages exist' do
        stage1.update_attributes!(prerequisite_stage_ids: [])
        result = render_view
        result.must_equal "\n"
      end
    end
  end
end
