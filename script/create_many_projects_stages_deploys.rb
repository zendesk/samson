#!/usr/bin/env ruby

# Creates lots of projects + stages + deploys with environments and deploy groups.

root = File.expand_path('..', File.dirname(__FILE__))
require File.expand_path('config/environment', root)

prod_env = Environment.unscoped.find_or_create_by!(name: 'Production', is_production: true)
stage_env = Environment.unscoped.find_or_create_by!(name: 'Staging')
master_env = Environment.unscoped.find_or_create_by!(name: 'Master')

pod1 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod1', environment: prod_env)
pod2 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod2', environment: prod_env)
pod3 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod3', environment: prod_env)
pod4 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod4', environment: prod_env)
pod5 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod5', environment: prod_env)
pod6 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod6', environment: prod_env)
pod98 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod98', environment: master_env)
pod99 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod99', environment: master_env)
pod100 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod100', environment: stage_env)
pod101 = DeployGroup.unscoped.find_or_create_by!(name: 'Pod101', environment: stage_env)

10.times do |i|
  if Project.unscoped.where(name: "Project #{i}").count == 0
    project = Project.create!(name: "Project #{i}", repository_url: "git@github.com:samson-test-org/example-project.git")
    project.stages.create!(name: "Production", deploy_groups: [pod1, pod2, pod3, pod4, pod5, pod6])
    project.stages.create!(name: "Staging", deploy_groups: [pod100, pod101])
    project.stages.create!(name: "Master", deploy_groups: [pod98, pod99])
    project.stages.create!(name: "Pod1", deploy_groups: [pod1])
    project.stages.create!(name: "Pod100", deploy_groups: [pod100])
    project.releases.create!(commit: "123456", author_id: 1, author_type: "User")

    job = Job.find_or_create_by!(command: 'true', user: User.first, project: project, status: 'succeeded', output: 'foobar', commit: 'master')

    rand(15).times do
      start_time = Time.now - rand(20.days)
      Deploy.create!(stage: project.stages.sample, job: job, reference: %w(master v1 v2 v4 v7 v9 v11 v12 v10 v6).sample, created_at: start_time, started_at: start_time, updated_at: (start_time + 10.minutes) )
    end
    print '.'
  end
end
