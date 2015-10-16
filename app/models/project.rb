class Project < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true

  validates :name, :repository_url, presence: true
  validate :valid_repository_url
  before_create :generate_token
  after_save :clone_repository, if: :repository_url_changed?
  before_update :clean_old_repository, if: :repository_url_changed?
  after_soft_delete :clean_repository

  has_many :builds
  has_many :releases
  has_many :stages, dependent: :destroy
  has_many :deploys, through: :stages
  has_many :jobs, -> { order(created_at: :desc) }
  has_many :webhooks
  has_many :commands
  has_many :macros
  has_many :user_project_roles
  has_many :users, through: :user_project_roles

  # For permission checks on callbacks. Currently used in private plugins.
  attr_accessor :current_user

  accepts_nested_attributes_for :stages

  scope :alphabetical, -> { order('name') }
  scope :with_deploy_groups, -> { includes(stages: [:deploy_groups]) }

  scope :ordered_for_user, ->(user) {
    select('projects.*, count(stars.id) as star_count').
      joins("left outer join stars on stars.user_id = #{sanitize(user.id)} and stars.project_id = projects.id").
      group('projects.id').
      order('star_count desc').
      alphabetical
  }

  scope :where_user_is_admin, ->(user) {
    joins(:user_project_roles).where(user_project_roles: {
        user_id: user.id,
        role_id: ProjectRole::ADMIN.id
    })
  }

  scope :search, ->(name) { where("name like ?", "%#{name}%") }

  def repo_name
    name.parameterize('_')
  end

  def docker_repo
    @docker_repo ||= begin
      registry = Rails.application.config.samson.docker.registry
      if Rails.env.production?
        "#{registry}/#{permalink_base}"
      else
        host, namespace = registry.split '/'
        namespace ||= 'samson'
        "#{host}/#{namespace}_non_prod/#{permalink_base}"
      end
    end
  end

  def last_release_contains_commit?(commit)
    last_release = releases.order(:id).last
    last_release && repository.downstream_commit?(last_release.commit, commit)
  end

  def auto_release_stages
    stages.deployed_on_release
  end

  def manage_releases?
    releases.any?
  end

  # Whether to create new releases when the branch is updated.
  #
  # branch - The String name of the branch in question.
  #
  # Returns true if new releases should be created, false otherwise.
  def create_releases_for_branch?(branch)
    release_branch == branch
  end

  # The user/repo part of the repository URL.
  def github_repo
    # GitHub allows underscores, hyphens and dots in repo names
    # but only hyphens in user/organisation names (as well as alphanumeric).
    repository_url.scan(/[:\/]([A-Za-z0-9-]+\/[\w.-]+?)(?:\.git)?$/).join
  end

  def repository_directory
    @repository_directory ||= Digest::MD5.hexdigest([repository_url, id].join)
  end

  def repository_homepage
    "//#{Rails.application.config.samson.github.web_url}/#{github_repo}"
  end

  def webhook_stages_for(branch, service_type, service_name)
    webhooks.for_source(service_type, service_name).for_branch(branch).map(&:stage)
  end

  def release_prior_to(release)
    releases.where('number < ?', release.number).order(:number).last
  end

  def repository
    @repository ||= GitRepository.new(repository_url: repository_url, repository_dir: repository_directory)
  end

  def with_lock(output: StringIO.new, holder:, error_callback: nil, timeout: 10.minutes, &block)
    callback = if error_callback.nil?
      proc { |owner| output.write("Waiting for repository while cloning for #{owner}\n") if Time.now.to_i % 10 == 0 }
    else
      error_callback
    end
    MultiLock.lock(id, holder, timeout: timeout, failed_to_lock: callback, &block)
  end

  def last_deploy_by_group(before_time)
    releases = deploys_by_group(before_time)
    releases.map { |group_id, deploys| [ group_id, deploys.sort_by(&:updated_at).last ] }.to_h
  end

  private

  def deploys_by_group(before)
    stages.each_with_object({}) do |stage, result|
      if deploy = stage.deploys.successful.where("deploys.updated_at <= ?", before.to_s(:db)).first
        stage.deploy_groups.each do |deploy_group|
          result[deploy_group.id] ||= []
          result[deploy_group.id] << deploy
        end
      end
    end
  end

  def permalink_base
    repository_url.to_s.split('/').last.to_s.sub(/\.git/, '')
  end

  def generate_token
    self.token = SecureRandom.hex
  end

  def clone_repository
    Thread.new do
      begin
        output = repository.executor.output
        with_lock(output: output, holder: 'Initial Repository Setup') do
          is_cloned = repository.clone!(from: repository_url, mirror: true)
          log.error("Could not clone git repository #{repository_url} for project #{name} - #{output.string}") unless is_cloned
        end
      rescue => e
       alert_clone_error!(e)
      end
    end
  end

  def clean_repository
    repository.clean!
  end

  def log
    Rails.logger
  end

  def clean_old_repository
    GitRepository.new(repository_url: repository_url_was, repository_dir: old_repository_dir).clean!
    @repository, @repository_directory = nil
  end

  def old_repository_dir
    Digest::MD5.hexdigest([repository_url_was, id].join)
  end

  def alert_clone_error!(exception)
    message = "Could not clone git repository #{repository_url} for project #{name}"
    log.error("#{message} - #{exception.message}")
    Airbrake.notify(exception,
      error_message: message,
      parameters: {
        project_id: id
      }
    )
  end

  def valid_repository_url
    unless repository.valid_url?
      errors.add(:repository_url, "is not valid or accessible")
    end
  end
end
