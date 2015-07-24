module KubernetesBuild
  extend ActiveSupport::Concern

  included do
    attr_writer :project_name, :container_port
    attr_accessor :env
  end

  def pod_name
    "#{project_name}-rc"
  end

  def project_name
    @project_name ||= project.name.parameterize('-')
  end

  def controller_name
    "#{project_name}-ctrl"
  end

  def service_name
    "#{project_name}-svc"
  end

  def version_label
    "#{project_name}-version-#{label}"
  end

  def container_port
    4242
  end

  def service_port
    8008
  end
end

Build.class_eval do
  include KubernetesBuild
end
