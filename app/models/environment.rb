# frozen_string_literal: true
class Environment < ActiveRecord::Base
  has_soft_deletion default_scope: true
  has_paper_trail skip: [:updated_at, :created_at]

  include Permalinkable

  has_many :deploy_groups
  has_many :template_stages, -> { where(is_template: true) }, through: :deploy_groups, class_name: 'Stage'
  has_one :lock, as: :resource

  validates_presence_of :name
  validates_uniqueness_of :name

  private

  def permalink_base
    name
  end
end
