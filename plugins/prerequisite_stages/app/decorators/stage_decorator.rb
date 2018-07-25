# frozen_string_literal: true
Stage.class_eval do
  prepend(Module.new do
    def prerequisite_stages
      prerequisite_stage_ids.any? ? Stage.where(id: prerequisite_stage_ids) : []
    end

    def unmet_prerequisite_stages(reference)
      commit = project.repository.commit_from_ref(reference)
      return [] unless commit && prereq_stages = prerequisite_stages.presence

      prereq_stages_with_deployed_ref = prereq_stages.joins(deploys: :job).where(
        jobs: {status: 'succeeded', commit: commit}
      )

      prereq_stages - prereq_stages_with_deployed_ref.uniq
    end
  end)

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
      errors[:base] << "Stage(s) #{deadlock_stages.join(', ')} already list this stage as a prerequisite."
      false
    else
      true
    end
  end
end
