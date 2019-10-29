# frozen_string_literal: true
class DeployBuild < ActiveRecord::Base
  belongs_to :deploy
  belongs_to :build
end
