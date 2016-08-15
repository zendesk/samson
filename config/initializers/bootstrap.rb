# frozen_string_literal: true
# Configures Rails for Twitter Bootstrap.

ActionView::Base.field_error_proc = proc do |html_tag, _instance_tag|
  %(<div class="has-error">#{html_tag}</div>).html_safe
end
