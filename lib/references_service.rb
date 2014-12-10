class ReferencesService

  attr_accessor :project, :output
  cattr_accessor(:lock_timeout, instance_writer: false) { 10.minutes }

  def initialize(project)
    @project = project
    @output = StringIO.new
  end

  def find_git_references
    return [] if @project.nil?
    Rails.cache.fetch(cache_key, :expires_in => references_ttl) do
      get_references_from_cached_repo
    end
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

  def references_hit_threshold
    Rails.application.config.samson.references_hit_threshold.to_i
  end

  def get_references_from_cached_repo
    git_references = nil
    lock_project do
      return unless repository.setup!(output, TerminalExecutor.new(output))
      git_references = repository.branches.merge(repository.tags).sort_by { |ref| [ref.length, ref] }
    end
    git_references
  end

  def lock_project(&block)
    holder = 'autocomplete'
    failed_to_lock = lambda do |owner|
      if Time.now.to_i % 10 == 0
        @output.write("Waiting for repository while cloning for: #{owner}\n")
      end
    end
    MultiLock.lock(project.id, holder, timeout: lock_timeout, failed_to_lock: failed_to_lock, &block)
  end

end

