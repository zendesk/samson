# frozen_string_literal: true
module BuildsHelper
  # shorten Docker SHAs "sha256:0123abc..." -> "0123abc"
  def short_sha(value, length: 7)
    value.split(':', 2).last.slice(0, length) if value
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
end
