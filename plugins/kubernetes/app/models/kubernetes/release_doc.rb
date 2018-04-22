# frozen_string_literal: true

require 'base64'

module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    serialize :resource_template, JSON
    delegate :desired_pod_count, :prerequisite?, to: :primary_resource
    delegate :build_selectors, to: :verification_template

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_create :store_resource_template

    attr_reader :previous_resources

    def deploy
      @previous_resources = resources.map(&:resource)
      resources.each(&:deploy)
    end

    def revert
      raise "Can only be done after a deploy" unless @previous_resources
      resources.each_with_index do |resource, i|
        resource.revert(@previous_resources[i])
      end
    end

    # run on unsaved mock ReleaseDoc to test template and secrets before we save or create a build
    # this create a bit of duplicated work, but fails the deploy fast
    def verify_template
      template = verification_template
      template.set_secrets
      template.verify_env
    end

    # kubeclient needs pure symbol hash ... not indifferent access
    def resource_template
      @resource_template ||= Array.wrap(super).map(&:deep_symbolize_keys)
    end

    def resources
      @resources ||= resource_template.map do |t|
        Kubernetes::Resource.build(
          t, deploy_group,
          autoscaled: kubernetes_role.autoscaled,
          delete_resource: delete_resource
        )
      end
    end

    # Temporary template we run validations on ... so can be cheap / not fully fleshed out
    # and only be the primary since services/configmaps are not very interesting anyway
    def verification_template
      primary_config = raw_template.detect { |e| Kubernetes::RoleConfigFile::PRIMARY_KINDS.include?(e.fetch(:kind)) }
      Kubernetes::TemplateFiller.new(self, primary_config, index: 0)
    end

    def blue_green_color
      kubernetes_release.blue_green_color if kubernetes_role.blue_green?
    end

    private

    def primary_resource
      resources.detect(&:primary?)
    end

    def resource_template=(value)
      @resource_template = nil
      super
    end

    # dynamically fill out the templates and store the result
    def store_resource_template
      counter = Hash.new(-1)
      secrets_vars = {}
      self.resource_template = raw_template.map do |resource|
        index = (counter[resource.fetch(:kind)] += 1)
        filter = TemplateFiller.new(self, resource, index: index)
        secrets_vars.merge!(filter.kubernetes_secret_entries)
        filter.to_hash
      end

      # Plus one document at the start for the secrets
      if secrets_vars.size > 0
        secrets_doc = {
          apiVersion: 'v1',
          kind: 'Secret',
          metadata: {
            name: "#{kubernetes_release.project.permalink}--#{kubernetes_role.name}--#{kubernetes_role_id}--#{kubernetes_release_id}".gsub('_', '-'),
            namespace: self.resource_template.first[:metadata][:namespace],
          },
          data: secrets_vars.map { |key, value| [key, Base64.strict_encode64(value)] }.to_h,
        }
        self.resource_template = [secrets_doc] + self.resource_template
      end
    end

    def validate_config_file
      return unless kubernetes_role
      raw_template # trigger RoleConfigFile validations
    rescue Samson::Hooks::UserError
      errors.add(:kubernetes_release, $!.message)
    end

    def raw_template
      @raw_template ||= begin
        file = kubernetes_role.config_file
        content = kubernetes_release.project.repository.file_content(file, kubernetes_release.git_sha)
        RoleConfigFile.new(content, file).elements
      end
    end
  end
end
