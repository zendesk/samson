class Command < ActiveRecord::Base
  has_many :stage_command
  has_many :stages, through: :stage_commands
  belongs_to :user

  validates :command, :user_id, presence: true
end
