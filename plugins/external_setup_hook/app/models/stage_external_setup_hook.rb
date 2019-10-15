# frozen_string_literal: true

class StageExternalSetupHook < ActiveRecord::Base
  self.table_name = 'external_setup_hook_stages'

  belongs_to :external_setup_hook, class_name: 'ExternalSetupHook', foreign_key: :external_setup_hook_id, inverse_of: :stage_external_setup_hooks
  belongs_to :stage, inverse_of: :stage_external_setup_hook

  validates :external_setup_hook, presence: true
  validates :stage, presence: true
end
