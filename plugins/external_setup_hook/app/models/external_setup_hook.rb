# frozen_string_literal: true

class ExternalSetupHook < ActiveRecord::Base
  validates :name, presence: true

  has_many :stage_external_setup_hooks, dependent: :destroy
  has_many :stages, through: :stage_external_setup_hooks, dependent: :destroy
end
