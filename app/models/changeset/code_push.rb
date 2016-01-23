class Changeset::CodePush
  attr_reader :repo, :data

  def initialize(repo, data)
    @repo = repo
    @data = data
  end

  def sha
    data[:after]
  end

  def branch
    data[:ref][/refs\/heads\/(.+)/, 1]
  end

  def event_type
    'push'
  end

  def service_type
    'code'
  end
end
