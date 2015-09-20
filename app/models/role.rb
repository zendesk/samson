require 'active_hash'

class Role < ActiveHash::Base
  include ActiveHash::Enum

  self.data = [
    { id: 0, name: "viewer", display_name: "Viewer" },
    { id: 1, name: "deployer", display_name: "Deployer" },
    { id: 2, name: "admin", display_name: "Admin" },
    { id: 3, name: "super_admin", display_name: "Super Admin" }
  ]

  enum_accessor :name
end
