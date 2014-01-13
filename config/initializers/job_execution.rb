config = Rails.application.config.pusher
JobExecution.enabled = config.enable_job_execution
JobExecution.cached_repos_dir = config.cached_repos_dir
