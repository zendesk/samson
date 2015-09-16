require 'active_hash'

class ProjectRole < ActiveHash::Base
  include ActiveHash::Enum

  self.data = [
    { id: 0, name: "deployer" },
    { id: 1, name: "admin" }
  ]

  enum_accessor :name
end
