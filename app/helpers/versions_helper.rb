# frozen_string_literal: true
module VersionsHelper
  def readable_ruby_value(v)
    v.class == BigDecimal ? v : v.inspect
  end
end
