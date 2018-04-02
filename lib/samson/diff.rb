# frozen_string_literal: true

require 'diffy'

module Samson
  module Diff
    # see https://github.com/samg/diffy
    def self.text_diff(a, b)
      Diffy::Diff.new(a, b).to_s(:html).html_safe
    end

    def self.style_tag
      "<style>#{Diffy::CSS}</style>".html_safe
    end
  end
end
