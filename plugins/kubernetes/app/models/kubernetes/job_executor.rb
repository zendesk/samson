# executes a deploy and writes log to job output
# finishes when cluster is "Ready"
module Kubernetes
  class JobExecutor < Executor
    def pid
      "Kubernetes-job-#{object_id}"
    end

    def stopped?
      false
    end

    private

    def execute_for(build)
      @job.update_attributes(build: build)
      create_job_docs(build).tap do |job_doc|
        run_job_docs(job_doc)
      end
    end

    def bad_pods(_job_docs)
      # TODO: What should be done here? Will do nothing in the meantime
      []
    end

    def wait_to_finish(job_docs)
      loop do
        break false if stopped?

        statuses = job_statuses(job_docs)

        print_statuses(statuses)
        if all_finished?(statuses)
          @output.puts "finished... "
          break all_completed?(statuses)
        end

        sleep TICK
      end
    end

    # create a release, storing all the configuration
    def create_job_docs(_build)
      job_docs = @job.stage.deploy_groups.map do |deploy_group|
        @job.job_docs.create(deploy_group_id: deploy_group.id)
      end

      unless job_docs.all?(&:persisted?)
        raise Samson::Hooks::UserError, "Failed to create job: #{job_docs.map(&:errors).map(&:full_messages).inspect}"
      end

      job_docs.each do |job_doc|
        @output.puts("Created job doc #{job_doc.id}")
      end

      job_docs
    end

    def print_statuses(statuses)
      statuses.each do |kubernetes_job|
        labels = kubernetes_job.metadata[:labels]
        status = kubernetes_job.status
        attempt_stats = {
          active:   status.active || 0,
          succeded: status.succeeded || 0,
          failed:   status.failed || 0
        }
        @output.puts("#{labels[:deploy_group]}: #{attempt_stats.to_json}")
      end
    end

    def all_finished?(statuses)
      statuses.all? do |kubernetes_job|
        last_condition = Array(kubernetes_job.status.conditions).last
        ["Complete", "Failed"].include?(last_condition.try(:type))
      end
    end

    def all_completed?(statuses)
      statuses.all? do |kubernetes_job|
        last_condition = Array(kubernetes_job.status.conditions).last
        last_condition.try(:type) == "Complete"
      end
    end

    def job_statuses(job_docs)
      job_docs.flat_map do |job_doc|
        query = {
          namespace: job_doc.kubernetes_namespace,
          label_selector: job_doc.job_selector.to_kuber_selector
        }
        job_doc.batch_client.get_jobs(query)
      end
    end

    def run_job_docs(job_docs)
      job_docs.each(&:run)
    end
  end
end
