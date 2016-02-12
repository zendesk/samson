require 'active_hash'

class ProjectRole < ActiveHash::Base
  include ActiveHash::Enum
  include ActiveModel::Serializers::JSON

  self.data = [
    { id: -1, name: "viewer" },
    { id: 0, name: "deployer" },
    { id: 1, name: "admin" }
  ]

  enum_accessor :name

  def display_name
    name.humanize
  end

  def as_json(options = {})
    super((options || {}).merge(methods: :display_name))
  end
end
