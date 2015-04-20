class Webhook < ActiveRecord::Base
  has_soft_deletion default_scope: true
  validates :branch, uniqueness: { scope: [ :stage ], conditions: -> { where("deleted_at IS NULL") }, message: "one webhook per (stage, branch) combination." }

  belongs_to :project
  belongs_to :stage

  SOURCES = Rails.root.join('app','controllers', 'integrations').children(false).map do |controller_path|
    controller_path.to_s[/\A(?!base)(\w+)_controller.rb\z/, 1]
  end.compact.freeze

  def self.for_branch(branch)
    where(branch: branch)
  end

  def self.for_source(service_type, service_name)
    where(source: [ 'any', "any_#{service_type}", service_name ])
  end
end
