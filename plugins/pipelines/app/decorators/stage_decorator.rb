# frozen_string_literal: true
Stage.class_eval do
  prepend SamsonPipelines::StageConcern
  serialize :next_stage_ids, Array # array of string ids.

  validate :valid_pipeline?, if: :next_stage_ids_changed?

  # duplicate call from models/stage.rb, but this is needed
  # to load the soft delete methods
  has_soft_deletion default_scope: true
end
