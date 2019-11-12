# frozen_string_literal: true
class EnvironmentVariableGroupOwner < ActiveRecord::Base
  belongs_to :environment_variable_group, inverse_of: :environment_variable_group_owners
  validates :name, presence: true
end
