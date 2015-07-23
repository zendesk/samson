Stage.class_eval do
  prepend SamsonPipelines::StageConcern
  serialize :next_stage_ids, Array

  validate :valid_pipeline?
end
