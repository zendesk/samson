# frozen_string_literal: true
class JenkinsJob < ActiveRecord::Base
  belongs_to :deploy
end
