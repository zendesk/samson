# frozen_string_literal: true

Stage.class_eval do
  has_one(
    :stage_external_setup_hook,
    class_name: 'StageExternalSetupHook',
    foreign_key: :stage_id,
    inverse_of: :stage,
    dependent: :destroy
  )
  has_one :external_setup_hook,
    class_name: 'ExternalSetupHook', through: :stage_external_setup_hook, source: :external_setup_hook, inverse_of: :stages

  accepts_nested_attributes_for(
    :stage_external_setup_hook,
    allow_destroy: true,
    update_only: true,
    reject_if: ->(h) { h[:external_setup_hook_id].blank? }
  )
end
