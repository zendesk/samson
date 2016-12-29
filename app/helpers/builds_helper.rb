# frozen_string_literal: true
module BuildsHelper
  def short_sha(value, length: 7)
    # with Docker, SHA values can be of the form "sha256:0123abc..."
    value.split(':').last[0..length].to_s if value
  end

  def git_ref_and_sha_for(build, make_link: false)
    return nil if build.git_ref.blank? && build.git_sha.blank?

    sha_text = short_sha(build.git_sha)
    sha_text = link_to(sha_text, build.commit_url) if make_link

    if build.git_ref
      # html-safe text surround
      sha_text.prepend "#{build.git_ref} ("
      sha_text.concat ")"
    end

    sha_text
  end

  def creator_for(build, method: :name_and_email)
    build.creator.try(method) || 'Trigger'
  end
end
