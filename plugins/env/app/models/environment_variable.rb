class EnvironmentVariable < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
  belongs_to :deploy_group
  validates :name, presence: true

  def self.env(stage, deploy_group_id)
    variables = stage.environment_variables + stage.environment_variable_groups.flat_map(&:environment_variables)
    variables.each_with_object({}) do |ev, all|
      if !ev.deploy_group_id
        all[ev.name] ||= ev.value
      elsif ev.deploy_group_id == deploy_group_id
        all[ev.name] = ev.value
      end
    end
  end
end
