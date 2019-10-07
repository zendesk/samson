# frozen_string_literal: true
Gem::Specification.new "samson_env", "0.0.0" do |s|
  s.summary =
    "Generate a .env file via stages ui for all deploy groups," \
    " validate it against the checked in .env keys, and ignores unwanted env keys"
  s.description =
    "Variables are prioritized by Stage, EnvironmentGroup then DeployGroup, EnvironmentGroup, All\n" \
    ".env.deploy-group-name files are generated when there are deploy groups assigned to the stage"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.add_runtime_dependency "aws-sdk-s3"
  s.add_runtime_dependency "dotenv"
end
