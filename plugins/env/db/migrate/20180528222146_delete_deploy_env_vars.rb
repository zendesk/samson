# frozen_string_literal: true
class DeleteDeployEnvVars < ActiveRecord::Migration[5.2]
  class Audit < ActiveRecord::Base
  end

  def change
    deploy_vars = EnvironmentVariable.where(parent_type: "Deploy").pluck(:id)
    Audit.where(auditable_type: "EnvironmentVariable", auditable_id: deploy_vars).delete_all
  end
end
