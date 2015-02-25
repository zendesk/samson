prod_env = Environment.create!(
  name: 'Production',
  is_production: true
)
Environment.create!(name: 'Staging')
Environment.create!(name: 'Master')

prod = DeployGroup.create!(
  name: 'Production',
  environment: prod_env
)

project = Project.create!(
  name: "Example-project",
  repository_url: "git@github.com:samson-test-org/example-project.git"
)

project.stages.create!(
  name: "Production",
  deploy_groups: [prod]
)
