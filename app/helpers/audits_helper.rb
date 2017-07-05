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
end
