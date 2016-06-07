module Kubernetes
  class JobYaml < Yaml
    JOB = 'Job'.freeze

    private

    def template
      @template ||= begin
        sections = YAML.load_stream(@doc.raw_template, @doc.template_name)
        if sections.size != 1
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} has #{sections.size} sections, currently having 1 section is valid."
          )
        elsif sections.first['kind'] != JOB
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} doesn't have a 'Job' section."
          )
        else
          RecursiveOpenStruct.new(sections.first, recurse_over_arrays: true)
        end
      end
    end

    def set_generate_name
      project_name = @doc.kubernetes_task.project.permalink
      task_name    = @doc.kubernetes_task.name
      template.metadata.generateName = "#{project_name}-#{task_name}-"
    end

    def set_timeout
      template.spec.activeDeadlineSeconds = 10.minutes
    end

    # Sets the labels for each new Pod.
    def set_job_labels
      job_doc_metadata.each do |key, value|
        template.metadata.labels[key] ||= value.to_s
      end
    end

    # have to match Kubernetes::Release#clients selector
    # TODO: dry
    def job_doc_metadata
      @job_doc_metadata ||= begin
        task         = @doc.kubernetes_task
        job          = @doc.job
        deploy_group = @doc.deploy_group
        build        = job.build
        project      = job.project

        job.job_selector(deploy_group).merge(
          deploy_group: deploy_group.env_value.parameterize,
          revision: build.git_sha,
          project_id: project.id,
          task_id: task.id,
          tag: build.git_ref.parameterize
        )
      end
    end
  end
end
