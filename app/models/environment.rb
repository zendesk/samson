# frozen_string_literal: true
class Environment < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true
  has_many :deploy_groups
  has_many :template_stages, -> { where(is_template: true) }, through: :deploy_groups, class_name: 'Stage'

  validates_presence_of :name
  validates_uniqueness_of :name

  private

  def permalink_base
    name
  end
end
