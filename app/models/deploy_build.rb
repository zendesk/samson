# frozen_string_literal: true
class DeployBuild < ActiveRecord::Base
  belongs_to :deploy, inverse_of: :deploy_builds
  belongs_to :build, inverse_of: :deploy_builds
end
Samson::Hooks.load_decorators(DeployBuild)
