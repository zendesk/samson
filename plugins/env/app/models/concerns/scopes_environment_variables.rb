# frozen_string_literal: true
module ScopesEnvironmentVariables
  ASSIGNABLE_ATTRIBUTES = {scoped_environment_variables_attributes: [:name, :value, :_destroy, :id]}.freeze

  def self.included(base)
    base.class_eval do
      has_many :scoped_environment_variables, as: :scope, dependent: :destroy, class_name: 'EnvironmentVariable'
    end
  end
end
