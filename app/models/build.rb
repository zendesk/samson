# frozen_string_literal: true
class Build < ActiveRecord::Base
  SHA1_REGEX = /\A[0-9a-f]{40}\Z/i
  SHA256_REGEX = /\A(sha256:)?[0-9a-f]{64}\Z/i
  DIGEST_REGEX = /\A[\w.-]+[\w\/-]*@sha256:[0-9a-f]{64}\Z/i
  ASSIGNABLE_KEYS = [:git_ref, :label, :description, :source_url] + Samson::Hooks.fire(:build_permitted_params)

  belongs_to :project
  belongs_to :docker_build_job, class_name: 'Job'
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by'
  has_many :deploys
  has_many :releases

  validates :project, presence: true
  validates :git_sha, format: SHA1_REGEX, allow_nil: true, uniqueness: true
  validates :docker_image_id, format: SHA256_REGEX, allow_nil: true
  validates :docker_repo_digest, format: DIGEST_REGEX, allow_nil: true
  validates :source_url, format: /\Ahttps?:\/\/\S+\z/, allow_nil: true

  validate :validate_git_reference, on: :create

  before_create :assign_number

  def nice_name
    "Build #{label.presence || id}"
  end

  def commit_url
    "#{project.repository_homepage}/tree/#{git_sha}"
  end

  def docker_status
    if docker_build_job
      docker_build_job.status
    elsif docker_repo_digest
      'built externally'
    else
      'not built'
    end
  end

  def create_docker_job
    create_docker_build_job(
      project: project,
      user_id: created_by || NullUser.new(0).id,
      command: '# Build docker image',
      commit:  git_sha,
      tag:     git_ref
    )
  end

  def docker_image
    @docker_image ||= Docker::Image.get(docker_image_id) if docker_image_id
  end

  def docker_image=(image)
    self.docker_image_id = image ? image.json['Id'] : nil
    @docker_image = image
  end

  def url
    Rails.application.routes.url_helpers.project_build_url(project, self)
  end

  private

  def validate_git_reference
    if git_ref.blank? && git_sha.blank?
      errors.add(:git_ref, 'must be specified')
      return
    end

    return if errors.include?(:git_ref) || errors.include?(:git_sha)

    unless project.repository.last_pulled
      project.with_lock(holder: 'Build reference validation') do
        project.repository.update_local_cache!
      end
    end

    if git_ref.present?
      commit = project.repository.commit_from_ref(git_ref)
      if commit
        self.git_sha = commit unless git_sha.present?
      else
        errors.add(:git_ref, 'is not a valid reference')
      end
    elsif git_sha.present?
      unless project.repository.commit_from_ref(git_sha)
        errors.add(:git_sha, 'is not a valid SHA for this project')
      end
    end
  end

  def assign_number
    biggest_number = project.builds.maximum(:number) || 0
    self.number = biggest_number + 1
  end
end
