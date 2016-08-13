# frozen_string_literal: true
class AddGitShaToKubernetesRelease < ActiveRecord::Migration
  class KubernetesRelease < ActiveRecord::Base
    belongs_to :build
  end

  def up
    [:git_sha, :git_ref].each do |attribute|
      if Build.where(attribute => nil).exists?
        raise "Delete all builds that do not have a #{attribute} and then re-run this migration"
      end
    end

    change_column_null :builds, :git_sha, false
    change_column_null :builds, :git_ref, false

    add_column :kubernetes_releases, :git_sha, :string, limit: 40
    add_column :kubernetes_releases, :git_ref, :string

    KubernetesRelease.find_each do |kr|
      kr.update_column(:git_sha, kr.build.git_sha)
      kr.update_column(:git_ref, kr.build.git_ref)
    end

    change_column_null :kubernetes_releases, :git_sha, false
    change_column_null :kubernetes_releases, :git_sha, false
  end

  def down
    remove_column :kubernetes_releases, :git_sha
    remove_column :kubernetes_releases, :git_ref
    change_column_null :builds, :git_sha, true
    change_column_null :builds, :git_ref, true
  end
end
