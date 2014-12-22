class MacroCommand < ActiveRecord::Base
  belongs_to :macro
  belongs_to :command, autosave: true
end
