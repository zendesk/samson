# frozen_string_literal: true

class AuditPresenter
  ## Presenter for Audit Logger

  AVAILABLE_PRESENTERS = [:user, :deploy]

  def self.present(object)
    unless (object.nil?)
      type = object.class.name.downcase.to_sym
      if AVAILABLE_PRESENTERS.include?(type)
        self.send(type, object)
      else
        object
      end
    end
  end

  def self.user(user)
    Audit::UserPresenter.present(user)
  end

  def self.deploy(deploy)
    Audit::DeployPresenter.present(deploy)
  end

  def self.project(project)
    Audit::ProjectPresenter.present(project)
  end
end
