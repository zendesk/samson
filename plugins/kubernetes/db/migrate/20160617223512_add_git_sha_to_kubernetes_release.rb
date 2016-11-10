# frozen_string_literal: true
class AddGitShaToKubernetesRelease < ActiveRecord::Migration[4.2]
  class KubernetesRelease < ActiveRecord::Base
    belongs_to :build
  end

  def up
    bad = [:git_sha, :git_ref].flat_map { |attribute| Build.where(attribute => nil).all.to_a }
    if bad.any?
      puts "Deleting bad builds: #{bad.map(&:attributes)}"
      bad.each(&:destroy!)
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
