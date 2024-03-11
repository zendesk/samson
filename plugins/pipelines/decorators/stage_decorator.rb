# frozen_string_literal: true
Stage.class_eval do
  prepend(
    Module.new do
      # Return true if any stages in the pipeline are marked production
      def production?(check_next_stages: true)
        super() || (check_next_stages && pipeline_next_stages.any?(&:production?))
      end

      def production_for_approval?
        production?(check_next_stages: false)
      end

      # Return true if any stages in the pipeline deploy to production
      def deploy_requires_approval?
        super || pipeline_next_stages.any?(&:deploy_requires_approval?)
      end
    end
  )

  serialize :next_stage_ids, Array

  validate :valid_pipeline?, if: :next_stage_ids_changed?

  after_destroy :remove_from_other_pipelines
  after_soft_delete :remove_from_other_pipelines

  def next_stage_ids=(*)
    super
    @pipeline_next_stages = nil
  end

  def pipeline_next_stages
    @pipeline_next_stages ||= next_stage_ids.any? ? Stage.where(id: next_stage_ids) : []
  end

  def pipeline_previous_stages
    @pipeline_previous_stages ||= project.stages.select { |stage| stage.next_stage_ids.include? id }
  end

  protected

  # Ensure we don't have a circular pipeline:
  #
  # potential race-condition if 2 stages are saved at same time:
  #   stageA saved with pipelines to stageB and stageC
  #   stageC saved with pipeline to stageA   => will validate if stageA above hasn't been written to DB yet
  def valid_pipeline?(origin_id = id)
    next_stage_ids.select!(&:presence)
    next_stage_ids.map!(&:to_i)

    if next_stage_ids.include?(origin_id)
      errors.add :base, "Stage #{name} causes a circular pipeline with this stage"
      return false
    end

    pipeline_next_stages.each do |stage|
      unless stage.valid_pipeline?(origin_id)
        errors.add :base, "Stage #{stage.name} causes a circular pipeline with this stage"
        return false
      end
    end
    true
  end

  def remove_from_other_pipelines
    (project.stages - [self]).each do |s|
      if s.next_stage_ids.delete(id)
        s.save(validate: false)
      end
    end
  end
end
