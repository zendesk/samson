require 'active_hash'

class Role < ActiveHash::Base
  include ActiveHash::Enum

  self.data = [
    { :id => 0, :name => "viewer" },
    { :id => 1, :name => "deployer" },
    { :id => 2, :name => "admin" }
  ]

  enum_accessor :name
end
