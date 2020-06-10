# frozen_string_literal: true
prod_env = Environment.create!(name: 'Production', production: true)
Environment.create!(name: 'Staging')
Environment.create!(name: 'Master')

group1 = DeployGroup.create!(
  name: 'Group1',
  environment: prod_env
)

project = Project.create!(
  name: "Example-project",
  repository_url: "https://github.com/samson-test-org/example-project.git"
)

project.stages.create!(
  name: "Production",
  deploy_groups: [group1]
)

User.create!(
  name: "Periodical",
  email: "periodical@example.com",
  external_id: Samson::PeriodicalDeploy::EXTERNAL_ID
)

user = User.create!(
  name: "Mr. Seed",
  email: "seed@example.com",
  external_id: "123"
)

project.releases.create!(
  commit: "1234" * 10,
  author: user
)

Samson::Hooks.plugins.each { |p| p.engine.load_seed }
