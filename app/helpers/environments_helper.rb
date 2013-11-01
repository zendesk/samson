module EnvironmentsHelper
  def select_valid_environments(project)
    project.environments.map {|env| [env, env]}
  end

  def valid_environment
    unless project.environments.include?(environment)
      errors.add(:environment, "is not included in #{project.environments.join(', ')}")
    end
  end
end
