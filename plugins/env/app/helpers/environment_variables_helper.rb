module EnvironmentVariablesHelper
  def env_deploygroup_array(include_all: true)
    all = include_all ? [["All", nil]] : []
    envs = Environment.all.map { |env| [env.name, "Environment-#{env.id}"] }
    separator = [["----", nil]]
    deploy_groups = DeployGroup.all.map { |dg| [dg.name, "DeployGroup-#{dg.id}"] }
    all + envs + separator + deploy_groups
  end
end
