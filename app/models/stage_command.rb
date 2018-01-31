# frozen_string_literal: true
class StageCommand < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :stage, optional: true
  belongs_to :command, autosave: true, optional: true

  validates :command, :stage, presence: true, if: :new_record?
end
