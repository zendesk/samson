class Build < ActiveRecord::Base
  SHA1_REGEX = /\A[0-9a-f]{40}\Z/i
  SHA256_REGEX = /\A[0-9a-f]{64}\Z/i

  belongs_to :project
  belongs_to :docker_build_job, class_name: 'Job'
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by'
  has_many :statuses, class_name: 'BuildStatus'
  has_many :deploys
  has_many :releases

  validates :project, presence: true
  validates :git_sha, format: SHA1_REGEX, allow_nil: true, uniqueness: true
  validates :docker_image_id, format: SHA256_REGEX, allow_nil: true

  validate :validate_git_reference, on: :create

  before_create :assign_number

  def nice_name
    "Build #{label.presence || id}"
  end

  def commit_url
    "#{project.repository_homepage}/tree/#{git_sha}"
  end

  def successful?
    statuses.all?(&:successful?)
  end

  def docker_build_output
    docker_build_job.try(:output)
  end

  def docker_status
    if docker_build_job
      docker_build_job.status
    else
      'not built'
    end
  end

  def create_docker_job
    create_docker_build_job(
      project: project,
      user_id: created_by || NullUser.new.id,
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

  def file_from_repo(path, ttl: 1.hour)
    Rails.cache.fetch([self, path], expire_in: ttl) do
      data = GITHUB.contents(project.github_repo, path: path, ref: git_sha)
      Base64.decode64(data[:content])
    end
  rescue Octokit::NotFound
    nil
  end

  private

  def validate_git_reference
    if git_ref.blank? && git_sha.blank?
      errors.add(:git_ref, 'must be specified')
      return
    end

    return if errors.include?(:git_ref) || errors.include?(:git_sha)

    project.with_lock(holder: 'Build reference validation') do
      project.repository.setup_local_cache!
    end

    if git_ref.present?
      commit = project.repository.commit_from_ref(git_ref, length: nil)
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
