# frozen_string_literal: true

module Kubernetes
  class BlueGreenDeployExecutor < DeployExecutor
    private

    # overrides
    def deploy_and_watch(release, release_docs)
      raise "does not support prerequisites" if release.release_docs != release_docs

      deploy_resources(release_docs)

      result = wait_for_resources_to_complete(release, release_docs)
      if result == true
        switch_service(release_docs)
        previous = release.previous_successful_release
        delete_resources(previous.release_docs) if previous && previous.blue_green_color != release.blue_green_color
        success
      else
        show_failure_cause(release, release_docs, result)
        delete_resources(release_docs)
        @output.puts "DONE"
        false
      end
    end

    def deploy_resources(release_docs)
      release_docs.each do |release_doc|
        @output.puts "Creating #{release_doc.blue_green_color.upcase} " \
          "resources for #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
        other_resources(release_doc).each(&:deploy)
      end
    end

    def switch_service(release_docs)
      release_docs.each do |release_doc|
        next unless service = service(release_doc)
        @output.puts "Switching service for #{release_doc.deploy_group.name} " \
          "role #{release_doc.kubernetes_role.name} to #{release_doc.blue_green_color.upcase}"
        service.deploy
      end
    end

    def delete_resources(release_docs)
      (release_docs || []).each do |release_doc|
        @output.puts "Deleting #{release_doc.blue_green_color.upcase} resources " \
          "for #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
        other_resources(release_doc).each(&:delete)
      end
    end

    def service(release_doc)
      release_doc.resources.detect { |r| r.is_a?(Kubernetes::Resource::Service) }
    end

    def other_resources(release_doc)
      release_doc.resources - Array(service(release_doc))
    end
  end
end
