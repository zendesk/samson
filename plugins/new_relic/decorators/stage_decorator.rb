# frozen_string_literal: true
Stage.class_eval do
  has_many :new_relic_applications, dependent: :destroy
  accepts_nested_attributes_for :new_relic_applications, allow_destroy: true, reject_if: :no_newrelic_name?

  private

  def no_newrelic_name?(newrelic_attrs)
    newrelic_attrs['name'].blank?
  end
end
