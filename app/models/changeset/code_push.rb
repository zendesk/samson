class Changeset::CodePush
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @data = data
  end

  def self.changeset_from_webhook(project, params = {})
    new(project.repo_name, params)
  end

  def sha
    data[:after]
  end

  def branch
    data[:ref][/refs\/heads\/(.+)/, 1]
  end

  def event_type
    'push' # Github's event name
  end

  def service_type
    'code' # Samson's webhook category
  end
end
