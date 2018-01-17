# frozen_string_literal: true

module Kubernetes
  class BlueGreenDeployExecutor < DeployExecutor
    def deploy_and_watch(release, release_docs)
      deploy_resources(release_docs)

      # wait for resources to be ready
      result = wait_for_resources_to_complete(release, release_docs)
      if result == true
        switch_service(release_docs)
        delete_previous_resources(release)
        success
      else
        show_failure_cause(release, release_docs, result)
        delete_resources(release_docs)
        @output.puts "DONE"
        false
      end
    end

    private

    def deploy_resources(release_docs)
      release_docs.each do |release_doc|
        @output.puts "Creating #{release_doc.blue_green_color.upcase}" \
                         "resources for #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
        release_doc.non_service_resources.each(&:deploy)
      end
      true
    end

    def switch_service(release_docs)
      release_docs.each do |release_doc|
        if release_doc.service_resource
          @output.puts "Switching service for #{release_doc.deploy_group.name}" \
                           "role #{release_doc.kubernetes_role.name} to #{release_doc.blue_green_color.upcase}"
          release_doc.service_resource.deploy
        end
      end
      true
    end

    def delete_previous_resources(release)
      delete_resources(release.previous_successful_release&.release_docs)
    end

    def delete_resources(release_docs)
      if release_docs
        release_docs.each do |release_doc|
          @output.puts "Deleting #{release_doc.blue_green_color.upcase} resources" \
                           "for #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
          release_doc.non_service_resources.each(&:delete)
        end
      end
      true
    end
  end
end
