# frozen_string_literal: true
class Macro < ActiveRecord::Base
  has_soft_deletion default_scope: true

  include HasCommands

  has_many :command_associations, autosave: true, class_name: "MacroCommand", dependent: :destroy
  has_many :commands, -> { order("macro_commands.position ASC") },
    through: :command_associations, auto_include: false

  belongs_to :project

  validates :name, presence: true, uniqueness: { scope: [:project, :deleted_at] }
  validates :reference, presence: true
end
