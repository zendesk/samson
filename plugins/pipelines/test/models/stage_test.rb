require_relative '../test_helper'

describe Stage do
  describe '#next_stage' do
    let(:project) { Project.new(name: 'foo') }
    let(:stage1) { Stage.new(project: project, name: 'stage1') }
    let(:stage2) { Stage.new(project: project, name: 'stage2') }
    let(:stage3) { Stage.new(project: project, name: 'stage3') }

    before do
      project.stages = [stage1, stage2, stage3]
    end

    it 'should return next created stage if no pipeline set' do
      stage2.next_stage.id.must_equal stage3.id
    end

    it 'should return next stage in pipeline if set' do
      stage2.next_stage_ids = [ stage1.id, stage3.id ]
      stage2.next_stage.id.must_equal stage1.id
    end
  end
end
