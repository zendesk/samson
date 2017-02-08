# frozen_string_literal: true
Stage.class_eval do
  prepend(Module.new do
    # Return true if any stages in the pipeline are marked production
    def production?
      super || next_stages.any?(&:production?)
    end
  end)

  serialize :next_stage_ids, Array

  validate :valid_pipeline?, if: :next_stage_ids_changed?

  # duplicate call from models/stage.rb, but this is needed
  # to load the soft delete methods
  has_soft_deletion default_scope: true

  def next_stages
    Stage.where(id: next_stage_ids)
  end

  def previous_stages
    @previous_stages ||= project.stages.select do |stage|
      stage.next_stage_ids.include? id
    end
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
      errors[:base] << "Stage #{name} causes a circular pipeline with this stage"
      return false
    end

    next_stages.each do |stage|
      unless stage.valid_pipeline?(origin_id)
        errors[:base] << "Stage #{stage.name} causes a circular pipeline with this stage"
        return false
      end
    end
    true
  end
end
