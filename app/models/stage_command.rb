# frozen_string_literal: true
class StageCommand < ActiveRecord::Base
  has_soft_deletion default_scope: true
  include SoftDeleteWithDestroy

  belongs_to :stage, inverse_of: :stage_commands
  belongs_to :command, autosave: true, inverse_of: :stage_commands
end
