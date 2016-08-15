# frozen_string_literal: true
class Project < ActiveRecord::Base
  include Permalinkable
  include Searchable

  has_soft_deletion default_scope: true

  validates :name, :repository_url, presence: true
  validate :valid_repository_url
  before_create :generate_token
  after_save :clone_repository, if: :repository_url_changed?
  before_update :clean_old_repository, if: :repository_url_changed?
  after_soft_delete :clean_repository
  before_soft_delete :destroy_user_project_roles

  has_many :builds
  has_many :releases
  has_many :stages, dependent: :destroy
  has_many :deploys, through: :stages
  has_many :jobs, -> { order(created_at: :desc) }
  has_many :webhooks
  has_many :commands
  has_many :macros, dependent: :destroy
  has_many :user_project_roles, dependent: :destroy
  has_many :users, through: :user_project_roles

  # For permission checks on callbacks. Currently used in private plugins.
  attr_accessor :current_user

  accepts_nested_attributes_for :stages

  scope :alphabetical, -> { order('name') }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  scope :with_deploy_groups, -> { includes(stages: [:deploy_groups]) }

  scope :ordered_for_user, ->(user) {
    select('projects.*, count(stars.id) as star_count').
      joins("left outer join stars on stars.user_id = #{sanitize(user.id)} and stars.project_id = projects.id").
      group('projects.id').
      order('star_count desc').
      alphabetical
  }

  scope :search, ->(name) { where("name like ?", "%#{name}%") }

  def docker_repo
    @docker_repo ||= begin
      registry = Rails.application.config.samson.docker.registry
      File.join(registry, ENV['DOCKER_REPO_NAMESPACE'].to_s, permalink_base)
    end
  end

  def last_release_contains_commit?(commit)
    last_release = releases.order(:id).last
    # status values documented here: http://stackoverflow.com/questions/23943855/github-api-to-compare-commits-response-status-is-diverged
    last_release && %w[behind identical].include?(GITHUB.compare(github_repo, last_release.commit, commit).status)
  rescue Octokit::NotFound
    false
  rescue Octokit::Error => e
    Airbrake.notify(e, parameters: { github_repo: github_repo, last_commit: last_release.commit, commit: commit })
    false # Err on side of caution and cause a new release to be created.
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
  def user_repo_part
    # GitHub allows underscores, hyphens and dots in repo names
    # but only hyphens in user/organisation names (as well as alphanumeric).
    repository_url.scan(%r{[:/]([A-Za-z0-9-]+/[\w.-]+?)(?:\.git)?$}).join
  end

  def github_repo
    user_repo_part
  end

  def gitlab_repo
    user_repo_part
  end

  def repository_directory
    @repository_directory ||= Digest::MD5.hexdigest([repository_url, id].join)
  end

  def webhook_stages_for(branch, service_type, service_name)
    webhooks.for_source(service_type, service_name).for_branch(branch).map(&:stage)
  end

  def repository_homepage
    if github?
      repository_homepage_github
    elsif gitlab?
      repository_homepage_gitlab
    else
      ""
    end
  end

  def github?
    repository_url.include? Rails.application.config.samson.github.web_url.split("://", 2).last
  end

  def gitlab?
    repository_url.include? Rails.application.config.samson.gitlab.web_url.split("://", 2).last
  end

  def release_prior_to(release)
    releases.where('number < ?', release.number).order(:number).last
  end

  def repository
    @repository ||= GitRepository.new(repository_url: repository_url, repository_dir: repository_directory)
  end

  def with_lock(output: StringIO.new, holder:, error_callback: nil, timeout: 10.minutes, &block)
    callback =
      if error_callback.nil?
        proc { |owner| output.write("Waiting for repository while cloning for #{owner}\n") if Time.now.to_i % 10 == 0 }
      else
        error_callback
      end
    MultiLock.lock(id, holder, timeout: timeout, failed_to_lock: callback, &block)
  end

  def last_deploy_by_group(before_time)
    releases = deploys_by_group(before_time)
    releases.map { |group_id, deploys| [group_id, deploys.sort_by(&:updated_at).last] }.to_h
  end

  private

  def repository_homepage_github
    "#{Rails.application.config.samson.github.web_url}/#{github_repo}"
  end

  def repository_homepage_gitlab
    "#{Rails.application.config.samson.gitlab.web_url}/#{gitlab_repo}"
  end

  def deploys_by_group(before)
    stages.each_with_object({}) do |stage, result|
      deploy = stage.deploys.successful.where(release: true).where("deploys.updated_at <= ?", before.to_s(:db)).first
      next unless deploy
      stage.deploy_groups.sort_by(&:natural_order).each do |deploy_group|
        result[deploy_group.id] ||= []
        result[deploy_group.id] << deploy
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
          unless is_cloned
            log.error("Could not clone git repository #{repository_url} for project #{name} - #{output.string}")
          end
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
    Airbrake.notify(
      exception,
      error_message: message,
      parameters: {
        project_id: id
      }
    )
  end

  def valid_repository_url
    return if repository.valid_url?
    errors.add(:repository_url, "is not valid or accessible")
  end

  def destroy_user_project_roles
    user_project_roles.each(&:destroy)
  end
end
