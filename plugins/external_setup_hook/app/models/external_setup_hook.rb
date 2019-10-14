# frozen_string_literal: true

class ExternalSetupHook < ActiveRecord::Base
  validates :name, presence: true
end
