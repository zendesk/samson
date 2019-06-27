# frozen_string_literal: true
module Inlinable
  def allow_inline(method)
    (allowed_inlines << method).flatten!
  end

  def allowed_inlines
    (@allowed_inlines ||= [])
  end
end
