# frozen_string_literal: true

namespace :maintenance do
  desc "move deploy groups between two stages for all projects. OWNER= FROM=dg1,dg2 TO=dg3,dg4 MOVE=dg2"
  task :move_deploy_group do
    projects = Project.where(owner: ENV.fetch("OWNER"))
    puts "found #{projects.size} projects"
    projects.each do |project|
      canary = project.stages.detect do |stage|
        stage.deploy_groups.map(&:permalink) == ENV.fetch("FROM").split(",")
      end
      phase1 = project.stages.detect do |stage|
        stage.deploy_groups.map(&:permalink) == ENV.fetch("TO").split(",")
      end
      puts "found #{project.name} -- #{canary&.name} -- #{phase1&.name}"
      next if !canary || !phase1
      canary.deploy_groups -= [DeployGroup.find_by_permalink(ENV.fetch("MOVE"))]
      phase1.deploy_groups += [DeployGroup.find_by_permalink(ENV.fetch("MOVE"))]
    end
  end
end
