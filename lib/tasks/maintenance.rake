# frozen_string_literal: true

namespace :maintenance do
  # FROM and TO can handle multiple deploy groups to not mess with projects that have each deploy group in a single stage.
  desc "move deploy groups between two stages for all projects. OWNER= FROM=dg1,dg2 TO=dg3,dg4 MOVE=dg2"
  task :move_deploy_group do
    projects = Project.where(owner: ENV.fetch("OWNER"))
    from = ENV.fetch("FROM").split(",")
    to = ENV.fetch("FROM").split(",")
    move = ENV.fetch("MOVE")
    move_group = DeployGroup.find_by_permalink!(move)

    raise "MOVE needs to be included in FROM" unless from.include? move
    puts "found #{projects.size} projects"

    projects.each do |project|
      from_stage = project.stages.detect { |stage| from & stage.deploy_groups.map(&:permalink) == from }
      to_stage = project.stages.detect { |stage| to & stage.deploy_groups.map(&:permalink) == to }

      puts "found #{project.name} -- from: #{from_stage&.name} -- to: #{to_stage&.name}"
      next if !from_stage || !to_stage || from_stage == to_stage
      from_stage.deploy_groups -= [move_group]
      to_stage.deploy_groups += [move_group]
      from_stage.destroy! if from_stage.deploy_groups.empty?
    end
  end
end
