# frozen_string_literal: true

namespace :maintenance do
  # FROM and TO handles multiple deploy groups to not mess with projects that have each deploy group in a single stage.
  desc "move deploy groups across stages for all projects. OWNER= FROM=dg1,dg2 TO=dg3,dg4 MOVE=dg2 [DELETE_EMPTY=true]"
  task move_deploy_group: :environment do
    projects = Project.where(owner: ENV.fetch("OWNER"))
    from = ENV.fetch("FROM").split(",")
    to = ENV.fetch("TO").split(",")
    move = ENV.fetch("MOVE")
    move_group = DeployGroup.find_by_permalink!(move)
    delete_empty = (ENV["DELETE_EMPTY"] == "true")

    raise "MOVE needs to be included in FROM" unless from.include? move
    puts "found #{projects.size} projects"

    actions = projects.map do |project|
      from_stage = project.stages.detect { |stage| from & stage.deploy_groups.map(&:permalink) == from }
      to_stage = project.stages.detect { |stage| to & stage.deploy_groups.map(&:permalink) == to }
      [project, from_stage, to_stage]
    end

    actions.select! do |project, from_stage, to_stage|
      if !from_stage
        puts "#{project.name} Unable to find FROM"
      elsif !to_stage
        puts "#{project.name} Unable to find TO"
      elsif from_stage == to_stage
        puts "#{project.name} FROM and TO are the same"
      else
        empty = (from_stage.deploy_groups == [move_group])
        puts "#{project.name} to be moved from:#{from_stage&.name}#{" (+ delete stage)" if empty} to:#{to_stage&.name}"
        true
      end
    end

    puts "Confirm? y/n"
    abort unless $stdin.gets.strip == "y"

    actions.each do |_, from_stage, to_stage|
      from_stage.deploy_groups -= [move_group]
      to_stage.deploy_groups += [move_group]
      from_stage.destroy! if delete_empty && from_stage.deploy_groups.empty?
    end
  end
end
