project = Project.create!(
  name: "Example-project",
  repository_url: "git@github.com:samson-test-org/example-project.git"
)

project.stages.create!(
  name: "Production"
)
