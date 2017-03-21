# frozen_string_literal: true
module AcceptsEnvironmentVariables
  ASSIGNABLE_ATTRIBUTES = {environment_variables_attributes: [:name, :value, :scope_type_and_id, :_destroy, :id]}.freeze

  def self.included(base)
    base.class_eval do
      has_many :environment_variables, as: :parent, dependent: :destroy
      accepts_nested_attributes_for :environment_variables, allow_destroy: true, reject_if: -> (a) { a[:name].blank? }
    end
  end
end
