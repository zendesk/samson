# frozen_string_literal: true

Stage.class_eval do
  validates(
    :external_setup_hook_id, allow_blank: true, numericality: { only_integer: true }
  )

  validate :validate_external_setup_hook_id

  private

  def validate_external_setup_hook_id
    unless external_setup_hook_id.blank? || ExternalSetupHook.exists?(external_setup_hook_id)
     errors.add(:external_setup_hook_id, "is invalid")
    end
  end
end
