DeployGroup.class_eval do
  def namespace
    name.parameterize('-')
  end
end
