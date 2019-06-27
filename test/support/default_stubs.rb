# frozen_string_literal: true
ActiveSupport::TestCase.class_eval do
  before { create_default_stubs }

  def create_default_stubs
    Project.any_instance.stubs(:clone_repository).returns(true)
    Project.any_instance.stubs(:clean_repository).returns(true)
  end

  def undo_default_stubs
    Project.any_instance.unstub(:clone_repository)
    Project.any_instance.unstub(:clean_repository)
  end
end
