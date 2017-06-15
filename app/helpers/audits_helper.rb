# frozen_string_literal: true
module AuditsHelper
  def readable_ruby_value(v)
    v.class == BigDecimal ? v : v.inspect
  end
end
