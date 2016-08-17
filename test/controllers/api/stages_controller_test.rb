# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::StagesController do
  assert_route :get, "/api/projects/1/stages",\
    to: "api/stages#index", params: { project_id: '1' }
  assert_route :post, "/api/stages/2/clone",\
    to: "api/stages#clone", params: { stage_id: "2" }
  assert_route :get, "/api/projects/1/stages/template_stage",\
    to: "api/stages#template_stage", params: { project_id: '1' }
  assert_route :put, "/api/projects/1/stages/2/template",\
    to: "api/stages#mark_template", params: { project_id: '1', id: "2" }
  assert_route :put, "/api/projects/1/stages/2/deploy_groups", \
    to: "api/stages#update", \
    params: {project_id: "1", id: "2"}

  oauth_setup!
  let(:project) { projects(:test) }
  let(:stages) { project.stages }

  describe 'get #index' do
    before do
      get :index, project_id: project.id
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
    it 'renders a cloned stage' do
      post :clone, stage_id: stages.first.id, stage: { name: "fooBy" }
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
        post :clone, stage_id: stage.id, stage: { name: 'NewProduction', deploy_group_ids: [dg.id] }
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
        params = { stage: { deploy_group_ids: [dg.id] } }
        @controller.stubs(:params).returns(ActionController::Parameters.new(params))
        @controller
      end

      it 'returns the deploy group matching the passed in ids' do
        subject.send(:deploy_groups).must_equal [dg]
      end
    end

    describe 'when the cloned stage is invalid' do
      before do
        post :clone, stage_id: stages.first.id, stage: { name: stages.first.name }
      end

      it 'does not clone' do
        assert_difference('Stage.count', 0) do
          post :clone, stage_id: stages.first.id, stage: { name: stages.first.name }
        end
      end

      it 'includes the errors' do
        post :clone, stage_id: stages.first.id, stage: { name: stages.first.name }
        response.body.must_include "already been taken"
      end
    end

    it 'creates a new stage' do
      assert_difference('Stage.count', 1) do
        post :clone, stage_id: stages.first.id, stage: { name: 'fooo' }
      end
    end
  end

  describe '#template_stage' do
    let(:project) { projects(:test) }
    let(:template_stage) { project.stages.first }

    before do
      project.template_stage!(template_stage)
      project.reload
      get :template_stage, project_id: project.id
    end

    subject { JSON.parse(response.body) }

    it 'succeeds' do
      assert_response :success
    end

    it 'uses the StageSerializer' do
      assert_serializer "StageSerializer"
    end

    it 'returns 404 when no template is set' do
      project.reset_template_stage!
      get :template_stage, project_id: project.id
      assert_response :not_found
    end
  end

  describe '#mark_template' do
    let(:project) { projects(:test) }
    let(:template_stage) { project.stages[0] }
    let(:non_template_stage) { project.stages[1] }

    before do
      project.template_stage!(template_stage)
      project.reload
      put :mark_template, project_id: project.id, id: non_template_stage.id
    end

    it 'responds with no_content' do
      assert_response :no_content
    end

    it 'updates the template stage for that project' do
      non_template_stage.reload.template?.must_equal true
      template_stage.reload.template?.must_equal false
    end

    it 'has only one template_stage' do
      project.stages.where(template: true).count.must_equal 1
    end

    describe '#stage' do
      it 'returns the stage for the id passed in' do
        @controller.send(:stage).must_equal non_template_stage
      end
    end
  end

  describe 'put #deploy_groups' do
    before do
      DeployGroup.stubs(:ensure_enabled).returns(true)
      @controller.stubs(:production_change?).returns(false)
      stage.deploy_groups.delete_all
      stage.deploy_groups.map(&:id).wont_include(dg.id)
      put :update, project_id: project.id, id: stage.id, \
                   stage: { deploy_group_ids: dg_ids }
    end

    let(:project) { projects(:test) }
    let(:stage) { project.stages.first }
    let(:dg) { deploy_groups(:pod100) }
    let(:dg_ids) { [dg.id] }

    it 'returns no_content' do
      assert_response :no_content
    end

    it 'sets the new deploy_group' do
      stage.reload.deploy_groups.map(&:id).must_include(dg.id)
    end

    describe 'multiple deploy_groups' do
      let(:dg1) { deploy_groups(:pod1) }
      let(:dg2) { deploy_groups(:pod2) }
      let(:dg_ids) { [dg1.id, dg2.id] }

      before do
        stage.deploy_groups_stages.delete_all
        stage.reload.deploy_groups.count.must_equal 0
        put :update, project_id: project.id, id: stage.id, \
                     stage: { deploy_group_ids: dg_ids }
      end

      it 'adds all the deploy groups' do
        stage.reload.deploy_groups.count.must_equal 2
        stage.deploy_groups.map(&:id).must_equal dg_ids
      end
    end
  end
end
