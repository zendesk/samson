class Ability
  include CanCan::Ability

  def initialize(user)

    if user.is_deployer?
      can :read, [ Project, Stage ]
      can [ :read, :execute ], Macro
      can :read, [ NewRelic, NewRelicApplication ]
      can :read, [ CommitStatus, ReferencesService ]
      can :create, Release
      can :manage, Webhook
      can [ :create ], Deploy
      can :manage, Lock do |lock|
        lock.stage_id.present?
      end
    end

    if user.is_admin?
      can :create, [ Job ]
      can :manage, [ Command, Project, Stage ]
      can [ :create, :update ], Macro
      can :admin_read, [ Project, DeployGroup, Environment, User ]
      can :manage, Lock
    end

    if user.is_super_admin?
      can [ :update, :destroy ], User
      can :manage, [ DeployGroup, Environment ]
    end

    can :destroy, [ Deploy, Job ] do |deploy_or_job|
      deploy_or_job.started_by?(user) || user.is_admin?
    end

    can :destroy, Macro do |macro|
      macro.user == user || user.is_super_admin?
    end

    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
  end
end
