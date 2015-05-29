Gem::Specification.new "samson_env", "0.0.0" do |s|
  s.summary = "Generate a .env file via stages ui for all deploy groups, validate it against the checked in .env keys, and ignores unwanted env keys"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.add_runtime_dependency "dotenv"
end
