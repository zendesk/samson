# frozen_string_literal: true
class JenkinsJob < ActiveRecord::Base
  has_paper_trail only:  [:name]
  belongs_to :deploy
end
