# frozen_string_literal: true
Project.prepend(Module.new do
  def docker_build_style_id=(value)
    super
    self.build_with_gcb = (value == 2)
  end

  def docker_build_style_id
    build_with_gcb ? 2 : super
  end
end)
