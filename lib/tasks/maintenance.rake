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
        puts "#{project.name} to be moved from:#{from_stage&.name}" \
          "#{" (+ delete stage)" if empty && delete_empty} to:#{to_stage&.name}"
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

  desc "delete deploy groups across stages for all projects. OWNER= DELETE=dg [DELETE_EMPTY=true]"
  task delete_deploy_group: :environment do
    projects = Project.where(owner: ENV.fetch("OWNER"))
    delete = ENV.fetch("DELETE")
    delete_group = DeployGroup.find_by_permalink!(delete)
    delete_empty = (ENV["DELETE_EMPTY"] == "true")

    puts "Found #{projects.size} projects"

    actions = projects.map do |project|
      from_stage = project.stages.detect { |stage| stage.deploy_groups.map(&:permalink).include? delete }
      [project, from_stage]
    end

    actions.select! do |project, from_stage|
      if !from_stage
        puts "Unable to find configured stage for #{delete_group.name} in #{project.name}"
      else
        empty = (from_stage.deploy_groups == [delete_group])
        puts "#{delete_group.name} to be removed from #{from_stage&.name} in " \
          "#{project.name} #{" (+ delete stage)" if empty && delete_empty}"
        true
      end
    end

    puts "Confirm? y/n"
    abort unless $stdin.gets.strip == "y"

    actions.each do |_, from_stage|
      from_stage.deploy_groups -= [delete_group]
      from_stage.destroy! if delete_empty && from_stage.deploy_groups.empty?
    end
  end
end
