require 'active_hash'

class Role < ActiveHash::Base
  include ActiveHash::Enum

  self.data = [
    { id: 0, name: "viewer" },
    { id: 1, name: "deployer" },
    { id: 2, name: "admin" },
    { id: 3, name: "super_admin" }
  ]

  enum_accessor :name

  def display_name
    name.humanize
  end
end
