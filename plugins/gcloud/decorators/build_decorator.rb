# frozen_string_literal: true
Build.class_eval do
  def gcr_id
    external_url.to_s[%r{/gcr/builds/([a-f\d-]+)}, 1]
  end
end
