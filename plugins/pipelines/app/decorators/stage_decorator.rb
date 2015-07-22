Stage.class_eval do
  serialize :next_stage_ids, Array

  puts "**** Stage Class Decorator is being eval'd"
  def next_stage
    return Stage.find(next_stage_ids.first) unless next_stage_ids.empty?
    stages = project.stages.to_a
    stages[stages.index(self) + 1]
  end

  alias_method :old_production?, :production?
  # Return true if any stages in the pipeline are marked production
  def production?
    return old_production? if next_stage_ids.empty?
    old_production? || Stage.find(job.deploy.stage.next_stage_ids).any?(:old_production?)
  end
end
