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
        stage1.update(production: true)
        stage1.production?.must_equal true
      end
    end

    describe "with pipeline without production" do
      before do
        stage1.update!(next_stage_ids: [stage3.id, stage2.id])
      end

      it 'is false if not marked production' do
        stage1.production?.must_equal false
      end

      it 'is true if marked production' do
        stage1.update(production: true)
        stage1.production?.must_equal true
      end
    end

    describe "with pipeline with production" do
      before do
        stage2.update(production: true)
        stage1.update!(next_stage_ids: [stage3.id, stage2.id])
      end

      it 'is true if not marked production' do
        stage1.production?.must_equal true
      end

      it "does not blow up on deleted next ids" do
        stage3.update_column(:deleted_at, Time.now)
        stage1.production?.must_equal true
      end

      it 'is true if marked production' do
        stage1.update(production: true)
        stage1.production?.must_equal true
      end
    end
  end

  describe '#valid_pipeline?' do
    it 'validates an empty pipeline' do
      stage1.valid?.must_equal true
    end

    it 'validates an empty params submission' do
      stage1.next_stage_ids = ['']
      stage1.valid?.must_equal true
      stage1.next_stage_ids.empty?.must_equal true
    end

    it 'validates a valid pipeline' do
      stage1.update!(next_stage_ids: [stage3.id, stage2.id])
      stage1.valid?.must_equal true
    end

    it 'invalidates a pipeline with itself in it' do
      stage1.update(next_stage_ids: [stage1.id])
      stage1.valid?.must_equal false
      stage1.errors.messages.must_equal base: ["Stage stage1 causes a circular pipeline with this stage"]
    end

    it 'invalidates a circular pipeline' do
      stage3.update!(next_stage_ids: [stage1.id])
      stage1.update(next_stage_ids: [stage3.id])
      stage1.valid?.must_equal false
      stage1.errors.messages.must_equal base: ["Stage stage3 causes a circular pipeline with this stage"]
    end

    it 'invalidates a bigger circular pipeline' do
      stage3.update!(next_stage_ids: [stage1.id])
      stage2.update!(next_stage_ids: [stage3.id])
      stage1.update(next_stage_ids: [stage2.id])
      stage1.valid?.must_equal false
      stage1.errors.messages.must_equal base: ["Stage stage2 causes a circular pipeline with this stage"]
    end

    it 'only validates if next_stage_ids changes' do
      Stage.any_instance.expects(:valid_pipeline?).never
      stage1.update!(order: 2)
      stage1.valid?.must_equal true
    end
  end

  describe '#verify_not_part_of_pipeline' do
    it 'allows soft delete if the stage is not part of a pipeline' do
      stage1.soft_delete.must_equal true
    end

    it 'returns false if this stage is referenced by another' do
      stage1.update!(next_stage_ids: [stage2.id])
      stage2.soft_delete.must_equal false
      stage2.errors.messages.must_equal base: ["Stage stage2 is in a pipeline from stage1 and cannot be deleted"]
    end
  end
end
