Project.class_eval do
  has_many :kubernetes_releases, through: :builds, class_name: 'Kubernetes::Release'
  has_many :roles, class_name: 'Kubernetes::Role'

  def file_from_repo(path, git_ref, ttl: 1.hour)
    # Caching by Git reference
    Rails.cache.fetch([git_ref, path], expire_in: ttl) do
      data = GITHUB.contents(github_repo, path: path, ref: git_ref)
      Base64.decode64(data[:content])
    end
  rescue Octokit::NotFound
    nil
  end

  def directory_contents_from_repo(path, git_ref, ttl: 1.hour)
    # Caching by Git reference
    Rails.cache.fetch([git_ref, path], expire_in: ttl) do
      GITHUB.contents(github_repo, path: path, ref: git_ref).map(&:path).select { |file_name|
        file_name.ends_with?('.yml', '.yaml', '.json')
      }
    end
  rescue Octokit::NotFound
    nil
  end

  # Imports the new kubernetes roles. This operation is atomic: if one role fails to be imported, none
  # of them will be persisted and the soft deletion will be rollbacked.
  def refresh_kubernetes_roles!(git_ref)
    config_files = directory_contents_from_repo('kubernetes', git_ref)

    unless config_files.to_a.empty?
      Project.transaction do
        roles.each(&:soft_delete!)

        kubernetes_config_files(config_files, git_ref) { |config_file|
          roles.create!(
            config_file: config_file.file_path,
            name: config_file.deployment.metadata.labels.role,
            service_name: config_file.service.name,
            ram: config_file.deployment.ram_mi,
            cpu: config_file.deployment.cpu_m,
            replicas: config_file.deployment.spec.replicas,
            deploy_strategy: config_file.deployment.strategy_type)
        }

        # Need to reload the project to refresh the association otherwise
        # the soft deleted roles will be rendered by the JSON serializer
        reload.roles
      end
    end
  end

  def name_for_label
    name.parameterize('-')
  end

  private

  # Given a list of kubernetes configuration files, retrieves the corresponding contents
  # and builds the corresponding Kubernetes Roles
  def kubernetes_config_files(config_files, git_ref)
    config_files.map do |file|
      file_contents = file_from_repo(file, git_ref)
      config_file = Kubernetes::RoleConfigFile.new(file_contents, file)
      yield config_file if block_given?
    end
  end
end
