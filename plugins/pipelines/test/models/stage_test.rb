require_relative '../test_helper'

describe Stage do
  let(:project) { Project.create!(name: 'foo', repository_url: 'random') }
  let(:stage1) { Stage.create!(project: project, name: 'stage1') }
  let(:stage2) { Stage.create!(project: project, name: 'stage2') }
  let(:stage3) { Stage.create!(project: project, name: 'stage3') }
  let(:production) { deploy_groups(:pod1) }
  let(:staging) { deploy_groups(:pod100) }
  let(:user) { User.find_by_name("Admin")}
  let(:job) {Job.create!({project: project, command: "sleep 100", status: "running", user: user})}

  before do
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    BuddyCheck.stubs(:enabled?).returns(true)
    project.stages = [stage1, stage2, stage3]
  end

  describe '#production?' do
    it 'returns false if no pipeline set and not marked production' do
      stage1.deploy_groups = [ staging ]
      stage1.production?.must_equal false
    end

    it 'returns true if no pipeline set and marked production' do
      stage1.update!(production: true)
      stage1.production?.must_equal true
    end

    it 'returns false if pipeline set but none are marked as production' do
      stage1.update!(next_stage_ids: [ stage3.id, stage2.id ])
      stage1.production?.must_equal false
    end

    it 'returns true if pipeline set and self is marked production' do
      stage1.update!(production: true)
      stage1.update!(next_stage_ids: [ stage3.id, stage2.id ])
      stage1.production?.must_equal true
    end

    it 'returns true if pipeline set and later stage is production' do
      stage2.update!(production: true)
      stage1.update!(next_stage_ids: [stage2.id ])
      stage1.deploy_requires_approval?.must_equal true
    end
  end

  describe '#deploy_requires_approval?' do
    before do
      BuddyCheck.stubs(:enabled?).returns(true)
      stage2.update!(next_stage_ids: [])
      stage2.update!(production: true)
      stage2.update!(deploy_groups: [ production ])
      stage3.update!(deploy_groups: [ production ])
      stage2.update!(no_code_deployed: true)
      stage1.update!(next_stage_ids: [ stage2.id ])
    end

    it 'does not require approval if a future stage has no_code_deployed' do
      stage2.deploy_requires_approval?.must_equal false
    end

    it 'requires approval with production deploy group and no_code_deployed false' do
      stage2.update!(no_code_deployed: false)
      stage1.deploy_requires_approval?.must_equal true
    end

    it 'does not require approval with production deploy group and no_code_deployed true' do
      stage2.update!(no_code_deployed: true)
      stage1.update!(next_stage_ids: [stage2.id ])
      stage1.deploy_requires_approval?.must_equal false
    end

    it 'requires approval with future chained stage production deploy group and no_code_deployed false' do
      stage2.update!(no_code_deployed: false)
      stage2.update!(deploy_groups: [ staging ])
      stage3.update!(no_code_deployed: false)
      stage1.update!(next_stage_ids: [stage2.id ])
      stage2.update!(next_stage_ids: [stage3.id ])
      stage1.deploy_requires_approval?.must_equal true
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
      stage1.update!(next_stage_ids: [ stage3.id, stage2.id ])
      stage1.valid?.must_equal true
    end

    it 'invalidates a pipeline with itself in it' do
      stage1.update(next_stage_ids: [ stage1.id ])
      stage1.valid?.must_equal false
      stage1.errors.messages.must_equal base: ["Stage stage1 causes a circular pipeline with this stage"]
    end

    it 'invalidates a circular pipeline' do
      stage3.update!(next_stage_ids: [ stage1.id ])
      stage1.update(next_stage_ids: [ stage3.id ])
      stage1.valid?.must_equal false
      stage1.errors.messages.must_equal base: ["Stage stage3 causes a circular pipeline with this stage"]
    end

    it 'invalidates a bigger circular pipeline' do
      stage3.update!(next_stage_ids: [ stage1.id ])
      stage2.update!(next_stage_ids: [ stage3.id ])
      stage1.update(next_stage_ids: [ stage2.id ])
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
      stage1.update!(next_stage_ids: [ stage2.id ])
      stage2.soft_delete.must_equal false
      stage2.errors.messages.must_equal base: ["Stage stage2 is in a pipeline from stage1 and cannot be deleted"]
    end
  end
end
