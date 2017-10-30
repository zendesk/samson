# frozen_string_literal: true
require 'diffy'

module AuditsHelper
  def readable_ruby_value(v)
    v.class == BigDecimal ? v : v.inspect
  end

  # see https://github.com/samg/diffy
  def text_diff(a, b)
    Diffy::Diff.new(a, b).to_s(:html).html_safe
  end

  def audit_author(audit)
    case audit.user
    when String
      "".html_safe << audit.user << " " << additional_info("System event")
    when User
      link_to_resource(audit.user)
    else
      "User##{audit.user_id}" if audit.user_id
    end
  end
end
