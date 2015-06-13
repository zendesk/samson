module BuildsHelper

  def build_page_title
    "#{@build.nice_name} - #{@project.name}"
  end

  def build_title build
    build.label.presence || "Build #{build.id}"
  end

  def short_sha value, length: 7
    "#{value.first(length)}" if value
  end

  def git_ref_and_sha_for build, make_link: false
    return nil if build.git_ref.blank? && build.git_sha.blank?

    sha_text = short_sha(build.git_sha)
    sha_text = link_to(sha_text, build.commit_url) if make_link

    if build.git_ref
      "#{build.git_ref} (#{sha_text})"
    else
      sha_text
    end
  end

  def creator_for build, method: :name_and_email
    build.creator.try(method) || 'Trigger'
  end

  def docker_build_running? build
    job = build.docker_build_job
    job && job.active? && (JobExecution.find_by_id(job.id) || JobExecution.enabled)
  end
end
