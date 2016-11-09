# frozen_string_literal: true

class AuditPresenter
  ## Presenter for Audit Logger

  AVAILABLE_PRESENTERS = [:user, :deploy]

  def self.present(object)
    return unless object
    type = object.class.name.underscore.to_sym
    if AVAILABLE_PRESENTERS.include?(type)
      self.send(type, object)
    else
      object
    end
  end

  def self.user(user)
    AuditPresenter::UserPresenter.present(user)
  end

  def self.deploy(deploy)
    AuditPresenter::DeployPresenter.present(deploy)
  end

  def self.project(project)
    AuditPresenter::ProjectPresenter.present(project)
  end
end
