module Samson
  class JobShellScript < ShellScript
    attr_accessor :output

    def initialize(job, reference, cache_dir, working_dir, output)
      @job = job
      @reference = reference
      @working_dir = working_dir
      @cache_dir = cache_dir
      super(output, verbose: true)
    end

    def commands
      @commands ||= [
        "export DEPLOYER=#{@job.user.email.shellescape}",
        "export DEPLOYER_EMAIL=#{@job.user.email.shellescape}",
        "export DEPLOYER_NAME=#{@job.user.name.shellescape}",
        "export REVISION=#{@reference.shellescape}",
        "export TAG=#{(@job.tag || @job.commit).to_s.shellescape}",
        "export CACHE_DIR=#{@cache_dir}",
        "cd #{@working_dir}",
        *@job.commands
      ]
    end

    def execute!
      super(*commands)
    end

    def self.display_name
      'Bash Script'
    end
  end
end
