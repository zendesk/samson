# frozen_string_literal: true
class AddUndecidedDeployGroupForInvalidStages < ActiveRecord::Migration[5.0]
  class DeployGroup < ActiveRecord::Base
  end

  class Environment < ActiveRecord::Base
  end

  class Stage < ActiveRecord::Base
  end

  class DeployGroupsStage < ActiveRecord::Base
  end

  def up
    return if ENV['DEPLOY_GROUP_FEATURE'].blank?
    return unless env = Environment.order('production desc').first
    group = DeployGroup.create!(
      name: 'Undecided',
      permalink: 'undecided',
      env_value: 'undecided',
      environment_id: env.id
    )

    stages = Stage.pluck(:id)
    used = DeployGroupsStage.pluck(:stage_id)
    undecided_stages = stages - used
    undecided_stages.each do |stage_id|
      DeployGroupsStage.create!(stage_id: stage_id, deploy_group_id: group.id)
    end
  end

  def down
  end
end
