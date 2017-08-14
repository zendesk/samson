# frozen_string_literal: true
class AddDailyDeploymemntToStages < ActiveRecord::Migration[5.1]
  EXTERNAL_ID = Samson::PeriodicalDeploy::EXTERNAL_ID

  class User < ActiveRecord::Base
  end

  def up
    add_column :stages, :periodical_deploy, :boolean, default: false, null: false
    User.create!(
      external_id: EXTERNAL_ID,
      name: "Periodical Deployer",
      integration: true,
      role_id: Role::DEPLOYER.id
    )
    write "Created user #{EXTERNAL_ID}"
  end

  def down
    remove_column :stages, :periodical_deploy
    User.where(external_id: EXTERNAL_ID).first&.soft_delete!(validate: false)
    write "Deleted user #{EXTERNAL_ID}"
  end
end
