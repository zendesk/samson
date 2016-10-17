# frozen_string_literal: true
class GitInfo
  @version = Gem::Version.new(`git --version`.scan(/\d+/).join('.'))

  class << self
    attr_reader :version
  end
end
