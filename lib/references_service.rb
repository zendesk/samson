class ReferencesService
  cattr_accessor(:lock_timeout, instance_writer: false) { 2.minutes }

  attr_reader :project

  def initialize(project)
    @project = project
  end

  def find_git_references
    Rails.cache.fetch(cache_key, :expires_in => references_ttl) { get_references_from_cached_repo }
  end

  def repository
    project.repository
  end

  def cache_key
    "#{project.id}_git_references"
  end

  def references_ttl
    Rails.application.config.samson.references_cache_ttl.to_i
  end

  def get_references_from_cached_repo
    git_references = nil
    lock_project do
      return unless repository.update!
      git_references = repository.branches.merge(repository.tags).sort_by { |ref| [-ref.length, ref] }.reverse
    end
    git_references
  end

  def lock_project(&block)
    project.with_lock(holder: 'autocomplete', timeout: lock_timeout, &block)
  end

  def output
    @output ||= StringIO.new
  end

end
