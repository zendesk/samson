# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::StagesController do
  oauth_setup!
  let(:project) { projects(:test) }
  let(:stages) { project.stages }

  describe 'get #index' do
    before do
      get :index, params: {project_id: project.id}, format: :json
    end

    subject { JSON.parse(response.body) }

    it 'succeeds' do
      assert_response :success
      response.content_type.must_equal 'application/json'
    end

    it 'contains a stage' do
      subject.size.must_equal 1
    end
  end

  describe 'post #clone' do
    describe '#stage_name' do
      before do
        @controller.stubs(:stage_to_clone).returns(stub(name: 'Foo'))
      end

      it 'returns copy of foo' do
        @controller.send(:stage_name).must_equal "Copy of Foo"
      end

      describe 'when the stage name is provided' do
        before do
          @controller.stubs(:params).returns(ActionController::Parameters.new(stage_name: "Foo"))
        end

        it 'uses the provided name' do
          @controller.send(:stage_name).must_equal "Foo"
        end
      end
    end

    it 'renders a cloned stage' do
      post :clone, params: {stage_id: stages.first.permalink}, format: :json
      assert_response :created
    end

    describe 'when deploy group id\'s are included' do
      let(:dg) do
        dg = deploy_groups(:pod1)
        dg.save!
        dg
      end

      before do
        stage.deploy_groups_stages.delete_all
        post :clone, format: :json, params: {
          stage_id: stage.permalink, deploy_group_ids: [dg.id], stage_name: 'NewProduction'
        }
      end

      let(:stage) { stages.first }
      subject do
        Stage.find_by_id JSON.parse(@response.body)['stage']['id']
      end

      it 'associates the newly cloned stage with the specified deploy groups' do
        subject.deploy_groups.size.must_equal 1, "More than one deploy group found for stage." \
          " #{stage.deploy_groups.to_a}"
        subject.deploy_groups.first.name.must_equal dg.name, "Wrong deploy group found " \
          "for stage: #{stage.deploy_groups.map(&:name)}"
      end
    end

    describe '#deploy_groups' do
      let(:dg) { deploy_groups(:pod1) }
      subject do
        @controller.stubs(:params).returns(ActionController::Parameters.new(deploy_group_ids: [dg.id]))
        @controller
      end

      it 'returns the deploy group matching the passed in ids' do
        subject.send(:deploy_groups).must_equal [dg]
      end
    end

    describe 'when the cloned stage is invalid' do
      before do
        post :clone, params: {stage_id: stages.first.permalink, stage_name: stages.first.name}, format: :json
      end

      it 'does not clone' do
        assert_difference('Stage.count', 0) do
          post :clone, params: {stage_id: stages.first.permalink, stage_name: stages.first.name}, format: :json
        end
      end

      it 'includes the errors' do
        post :clone, params: {stage_id: stages.first.permalink, stage_name: stages.first.name}, format: :json
        response.body.must_include "already been taken"
      end
    end

    it 'creates a new stage' do
      assert_difference('Stage.count', 1) do
        post :clone, params: {stage_id: stages.first.permalink}, format: :json
      end
    end
  end
end
