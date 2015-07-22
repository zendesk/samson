module Stage::PipelineProductionEnhancer
  # Return true if any stages in the pipeline are marked production
  def production?(check_next: true)
    super || (
      check_next &&
        next_stage_ids.any? &&
        Stage.find(job.deploy.stage.next_stage_ids).any? { |s| s.production?(check_next: false) }
    )
  end
end

Stage.class_eval do
  prepend Stage::PipelineProductionEnhancer
  serialize :next_stage_ids, Array

  def next_stage
    return Stage.find(next_stage_ids.first) unless next_stage_ids.empty?
    stages = project.stages.to_a
    stages[stages.index(self) + 1]
  end
end
