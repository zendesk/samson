# frozen_string_literal: true
require 'diffy'

module AuditsHelper
  def readable_ruby_value(v)
    v.instance_of?(BigDecimal) ? v : v.inspect
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
