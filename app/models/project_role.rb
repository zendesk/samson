require 'active_hash'

class ProjectRole < ActiveHash::Base
  include ActiveHash::Enum

  self.data = [
    { id: 0, name: "deployer", display_name: "Deployer" },
    { id: 1, name: "admin", display_name: "Admin" }
  ]

  enum_accessor :name
end
