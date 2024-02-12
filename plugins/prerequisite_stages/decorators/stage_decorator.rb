# frozen_string_literal: true
Stage.class_eval do
  prepend(
Module.new do
  def prerequisite_stages
    prerequisite_stage_ids.any? ? Stage.where(id: prerequisite_stage_ids) : []
  end

  def undeployed_prerequisite_stages(commit)
    return [] unless stages = prerequisite_stages.presence

    deployed_stages = stages.joins(deploys: :job).where(
      jobs: {status: 'succeeded', commit: commit}
    )

    stages - deployed_stages
  end
end
)

  serialize :prerequisite_stage_ids, Array

  validate :validate_prerequisites, if: :prerequisite_stage_ids_changed?

  private

  def validate_prerequisites
    prerequisite_stage_ids.select!(&:presence)
    prerequisite_stage_ids.map!(&:to_i)

    other_prerequisite_ids = prerequisite_stages.pluck(:name, :prerequisite_stage_ids)
    deadlock_stages = other_prerequisite_ids.each_with_object([]) do |(name, prereq_ids), stages|
      stages << name if prereq_ids.include?(id)
    end

    if deadlock_stages.any?
      errors.add :base, "Stage(s) #{deadlock_stages.join(', ')} already list this stage as a prerequisite."
      false
    else
      true
    end
  end
end
