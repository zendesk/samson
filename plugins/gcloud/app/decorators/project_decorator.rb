# frozen_string_literal: true
Project.class_eval do
  validate :validate_not_using_gcb_and_external

  private

  def validate_not_using_gcb_and_external
    return unless build_with_gcb && docker_image_building_disabled
    errors.add(:build_with_gcb, "cannot be enabled when Docker images are built externally")
  end
end
