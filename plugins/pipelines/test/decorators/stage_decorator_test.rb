# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:project) { Project.create!(name: 'foo', repository_url: 'random') }
  let(:stage1) { Stage.create!(project: project, name: 'stage1') }
  let(:stage2) { Stage.create!(project: project, name: 'stage2') }
  let(:stage3) { Stage.create!(project: project, name: 'stage3') }
  let(:production) { deploy_groups(:pod1) }
  let(:staging) { deploy_groups(:pod100) }

  before do
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    project.stages = [stage1, stage2, stage3]
  end

  describe '#production?' do
    describe "without pipeline" do
      it 'is false if not marked production' do
        stage1.production?.must_equal false
      end

      it 'is true if marked production' do
        stage1.update_columns(production: true)
        stage1.production?.must_equal true
      end
    end

    describe "with pipeline without production" do
      before do
        stage1.update_columns(next_stage_ids: [stage3.id, stage2.id])
      end

      it 'is false if not marked production' do
        stage1.production?.must_equal false
      end

      it 'is true if marked production' do
        stage1.update_columns(production: true)
        stage1.production?.must_equal true
      end
    end

    describe "with pipeline with production" do
      before do
        stage2.update_columns(production: true)
        stage1.update_columns(next_stage_ids: [stage3.id, stage2.id])
      end

      it 'is true if not marked production' do
        stage1.production?.must_equal true
      end

      it "does not blow up on deleted next ids" do
        stage3.update_column(:deleted_at, Time.now)
        stage1.production?.must_equal true
      end

      it 'is true if marked production' do
        stage1.update_columns(production: true)
        stage1.production?.must_equal true
      end

      it 'is true for production in nested child node' do
        stage1.update_columns(next_stage_ids: [stage3.id])
        stage3.update_columns(next_stage_ids: [stage2.id])
        stage1.production?.must_equal true
      end
    end
  end

  describe '#deploy_requires_approval?' do
    with_env BUDDY_CHECK_FEATURE: 'true'

    it 'is required when going to prod' do
      stage1.production = true
      assert stage1.deploy_requires_approval?
    end

    it 'is not required when going to staging' do
      refute stage1.deploy_requires_approval?
    end

    describe 'with a pipelined stage going to prod' do
      before do
        stage2.update_column(:production, true)
        stage1.update!(next_stage_ids: [stage2.id])
      end

      it 'is required' do
        assert stage1.deploy_requires_approval?
      end

      it 'is not required when not deploying' do
        stage1.pipeline_next_stages.first.no_code_deployed = true
        refute stage1.deploy_requires_approval?
      end
    end
  end

  describe '#pipeline_next_stages' do
    it 'does not query when empty' do
      assert_sql_queries(0) { stage1.pipeline_next_stages.must_equal [] }
    end

    it 'queries when filled' do
      stage1.next_stage_ids = [stage2.id]
      assert_sql_queries(1) { stage1.pipeline_next_stages.must_equal [stage2] }
    end
  end

  describe '#valid_pipeline?' do
    it 'validates an empty pipeline' do
      assert_valid stage1
    end

    it 'validates an empty params submission' do
      stage1.next_stage_ids = ['']
      assert_valid stage1
      stage1.next_stage_ids.empty?.must_equal true
    end

    it 'validates a valid pipeline' do
      stage1.next_stage_ids = [stage3.id, stage2.id]
      assert_valid stage1
    end

    it 'invalidates a pipeline with itself in it' do
      stage1.next_stage_ids = [stage1.id]
      refute_valid stage1
      stage1.errors.messages.must_equal base: ["Stage stage1 causes a circular pipeline with this stage"]
    end

    it 'invalidates a circular pipeline' do
      stage3.update_columns(next_stage_ids: [stage1.id])
      stage1.next_stage_ids = [stage3.id]
      refute_valid stage1
      stage1.errors.messages.must_equal base: ["Stage stage3 causes a circular pipeline with this stage"]
    end

    it 'invalidates a bigger circular pipeline' do
      stage3.update_columns(next_stage_ids: [stage1.id])
      stage2.update_columns(next_stage_ids: [stage3.id])
      stage1.next_stage_ids = [stage2.id]
      refute_valid stage1
      stage1.errors.messages.must_equal base: ["Stage stage2 causes a circular pipeline with this stage"]
    end

    it 'only validates if next_stage_ids changes' do
      Stage.any_instance.expects(:valid_pipeline?).never
      stage1.order = 2
      stage1.save!
      assert_valid stage1
    end
  end

  describe '#pipeline_previous_stages' do
    it 'works with an empty pipeline' do
      stage1.pipeline_previous_stages.must_equal []
    end

    it 'returns stages correctly' do
      # Set both stage1 and stage2 to trigger stage3
      stage1.update_columns(next_stage_ids: [stage3.id])
      stage2.update_columns(next_stage_ids: [stage3.id])

      stage3.pipeline_previous_stages.sort.must_equal [stage1, stage2]
      stage1.pipeline_previous_stages.must_equal []
    end
  end

  describe "destroy" do
    it "removes the stage from the pipeline of other stages" do
      other_stage = project.stages.create!(name: 'stage4', next_stage_ids: [stage1.id])
      assert other_stage.next_stage_ids.include?(stage1.id)
      stage1.soft_delete!(validate: false)
      refute other_stage.reload.next_stage_ids.include?(stage1.id)
    end
  end
end
